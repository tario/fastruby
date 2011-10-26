=begin

This file is part of the fastruby project, http://github.com/tario/fastruby

Copyright (c) 2011 Roberto Dario Seminara <robertodarioseminara@gmail.com>

fastruby is free software: you can redistribute it and/or modify
it under the terms of the gnu general public license as published by
the free software foundation, either version 3 of the license, or
(at your option) any later version.

fastruby is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.  see the
gnu general public license for more details.

you should have received a copy of the gnu general public license
along with fastruby.  if not, see <http://www.gnu.org/licenses/>.

=end
module FastRuby
  module BlockTranslator
    
    register_translator_module self
    
    def to_c_yield(tree)

      block_code = proc { |name| "
        static VALUE #{name}(VALUE frame_param, VALUE* block_args, int size) {

          #{@locals_struct} *plocals;
          #{@frame_struct} *pframe;
          pframe = (void*)frame_param;
          plocals = (void*)pframe->plocals;

          if (FIX2LONG(plocals->block_function_address) == 0) {
            #{_raise("rb_eLocalJumpError", "no block given")};
          } else {
            return ((VALUE(*)(int,VALUE*,VALUE,VALUE))FIX2LONG(plocals->block_function_address))(size, block_args, FIX2LONG(plocals->block_function_param), (VALUE)pframe);
          }
        }
      "
      }

      new_yield_signature = tree[1..-1].map{|subtree| infer_type subtree}
      # merge the new_yield_signature with the new
      if @yield_signature
        if new_yield_signature.size == @yield_signature.size
          (0..new_yield_signature.size-1).each do |i|
            if @yield_signature[i] != new_yield_signature[i]
              @yield_signature[i] = nil
            end
          end
        else
          @yield_signature = new_yield_signature.map{|x| nil}
        end
      else
        @yield_signature = new_yield_signature
      end

      splat_arg = tree.find{|x| x == :yield ? false : x[0] == :splat}
      ret = nil      
      if splat_arg
        ret = inline_block "
          VALUE splat_array = #{to_c(splat_arg[1])};
          
          if (CLASS_OF(splat_array) == rb_cArray) {
            VALUE block_args[RARRAY(splat_array)->len + #{tree.size}];
            int i;
            #{ 
              (0..tree.size-3).map{|i|
                "block_args[#{i}] = #{to_c(tree[i+1])}"
              }.join(";\n")
            };
            
            for (i=0; i<RARRAY(splat_array)->len; i++) {
              block_args[i+#{tree.size-2}] = rb_ary_entry(splat_array,i);
            }
            
            return #{anonymous_function(&block_code)}((VALUE)pframe, block_args, RARRAY(splat_array)->len + #{tree.size-2});
          } else {
            VALUE block_args[1+#{tree.size}];
            #{ 
              (0..tree.size-3).map{|i|
                "block_args[#{i}] = #{to_c(tree[i+1])}"
              }.join(";\n")
            };
            
            block_args[#{tree.size-2}] = splat_array;
            return #{anonymous_function(&block_code)}((VALUE)pframe, block_args, #{tree.size-1});
          }
          
        "
      else
        ret = if tree.size > 1
            anonymous_function(&block_code)+"((VALUE)pframe, (VALUE[]){#{tree[1..-1].map{|subtree| to_c subtree}.join(",")}},#{tree.size-1})"
          else
            anonymous_function(&block_code)+"((VALUE)pframe, (VALUE[]){}, #{tree.size-1})"
          end
      end
      
      protected_block(ret, false)
    end

    def to_c_block(tree)
      if tree.size == 1
        return inline_block("return Qnil;")
      end

      str = ""
      str = tree[1..-2].map{ |subtree|
        to_c(subtree)
      }.join(";")

      if tree[-1]

        if tree[-1][0] != :return
          str = str + ";last_expression = #{to_c(tree[-1])};"
        else
          str = str + ";#{to_c(tree[-1])};"
        end
      end

      str << "return last_expression;"

      inline_block str
    end
    
  end
end
