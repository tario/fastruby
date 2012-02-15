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
  class Context

    define_translator_for(:yield, :method => :to_c_yield, :arity => 1)
    def to_c_yield(tree)

      block_code = proc { |name| "
        static VALUE #{name}(VALUE frame_param, VALUE* block_args, int size) {

          #{@locals_struct} *plocals;
          #{@frame_struct} *pframe;
          pframe = (void*)frame_param;
          plocals = (void*)pframe->plocals;

          if ((plocals->block_function_address) == 0) {
            #{_raise("rb_eLocalJumpError", "no block given")};
          } else {
            return ((VALUE(*)(int,VALUE*,VALUE,VALUE))(plocals->block_function_address))(size, block_args, (VALUE)(plocals->block_function_param), (VALUE)pframe);
          }
        }
      "
      }

      splat_arg = tree.find{|x| x == :yield ? false : x[0] == :splat}

      protected_block(false) do
        if splat_arg
          "
            VALUE splat_array = Qnil;
            VALUE block_aux = Qnil;
             #{to_c(splat_arg[1], "splat_array")};
            
            if (CLASS_OF(splat_array) == rb_cArray) {
              VALUE block_args[_RARRAY_LEN(splat_array) + #{tree.size}];
              int i;
              #{ 
                (0..tree.size-3).map{|i|
                  "
                  #{to_c(tree[i+1], "block_aux")};
                  block_args[#{i}] = block_aux;
                  "
                }.join(";\n")
              };
              
              for (i=0; i<_RARRAY_LEN(splat_array); i++) {
                block_args[i+#{tree.size-2}] = rb_ary_entry(splat_array,i);
              }
              
              last_expression = #{anonymous_function(&block_code)}((VALUE)pframe, block_args, _RARRAY_LEN(splat_array) + #{tree.size-2});
            } else {
              VALUE block_args[1+#{tree.size}];
              #{ 
                (0..tree.size-3).map{|i|
                  "
                  #{to_c(tree[i+1], "block_aux")};
                  block_args[#{i}] = block_aux;
                  "
                }.join(";\n")
              };
              
              block_args[#{tree.size-2}] = splat_array;
              last_expression = #{anonymous_function(&block_code)}((VALUE)pframe, block_args, #{tree.size-1});
            }
            
          "
        else
          if tree.size > 1
              "last_expression = " + anonymous_function(&block_code)+"((VALUE)pframe, (VALUE[]){#{tree[1..-1].map{|subtree| to_c subtree}.join(",")}},#{tree.size-1})"
            else
              "last_expression = " + anonymous_function(&block_code)+"((VALUE)pframe, (VALUE[]){}, #{tree.size-1})"
            end
        end
      end
    end

    define_translator_for(:block, :method => :to_c_block)
    def to_c_block(tree, result_variable = nil)
      if tree.size == 1
        return inline_block("return Qnil;")
      end
      
      str = ""
      str = tree[1..-2].map{ |subtree|
        to_c(subtree,"last_expression")
      }.join(";")

      if tree[-1]
          str = str + ";#{to_c(tree[-1],"last_expression")};"
      end

      if result_variable
        str << "#{result_variable} = last_expression;"
        str
      else
        str << "return last_expression;"
        inline_block str
      end
    end
    
  end
end
