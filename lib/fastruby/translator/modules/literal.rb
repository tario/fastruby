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
  module LiteralTranslator
    register_translator_module self

    def to_c_lit(tree)
      literal_value tree[1]
    end

    def to_c_nil(tree)
      "Qnil"
    end

    def to_c_str(tree)
      literal_value tree[1]
    end

    def to_c_hash(tree, result_var = nil)
      
      hash_tmp_var = "_hash_"+rand(1000000).to_s
      key_tmp_var = "_key_"+rand(1000000).to_s
      value_tmp_var = "_value_"+rand(1000000).to_s

      hash_aset_code = ""
      (0..(tree.size-3)/2).each do |i|
        strkey = to_c tree[1 + i * 2]
        strvalue = to_c tree[2 + i * 2]
        hash_aset_code << "
          {
            VALUE #{key_tmp_var} = Qnil;
            VALUE #{value_tmp_var} = Qnil;
            
            #{to_c tree[1 + i * 2], key_tmp_var};
            #{to_c tree[2 + i * 2], value_tmp_var};
            
            rb_hash_aset(#{hash_tmp_var}, #{key_tmp_var}, #{value_tmp_var});
          }
        "
      end
      
        code = "
          {
          VALUE #{hash_tmp_var} = rb_hash_new();
          #{hash_aset_code};
          #{
          if result_var
            "#{result_var} = #{hash_tmp_var}"
          else
            "return #{hash_tmp_var}"
          end
          };
          }
        "
        
      if result_var
        code
      else
        inline_block code
      end
    end

    def to_c_array(tree, result_var = nil)
      if tree.size > 1
        if result_var
          prefix = "_array_element_" + rand(10000000).to_s + "_"
          "
          {
            #{ 
              (0..tree.size-2).map{|x|
                "VALUE #{prefix}#{x};"
              }.join("\n");
            }
            
            #{
              (0..tree.size-2).map{|x|
                to_c(tree[x+1], prefix+x.to_s)
              }.join("\n");
            }
            
            #{result_var} = rb_ary_new3(#{tree.size-1}, #{(0..tree.size-2).map{|x| prefix+x.to_s}.join(",")} );
          }
          "
        else
          strargs = tree[1..-1].map{|subtree| to_c subtree}.join(",")
          "rb_ary_new3(#{tree.size-1}, #{strargs})"
        end
      else
        if result_var
        "#{result_var} = rb_ary_new3(0);"
        else
        "rb_ary_new3(0)"
        end
      end
    end

    def to_c_self(tree)
      locals_accessor + "self"
    end

    def to_c_false(tree)
      "Qfalse"
    end

    def to_c_true(tree)
      "Qtrue"
    end

    def to_c_dot2(tree, result_var = nil)
      
      begin_var = "_begin"+rand(10000000).to_s
      end_var = "_end"+rand(10000000).to_s
      
      if result_var
        "
        {
          VALUE #{begin_var} = Qnil;
          VALUE #{end_var} = Qnil;
          
          #{to_c tree[1], begin_var};
          #{to_c tree[2], end_var};
          
          #{result_var} = rb_range_new(#{begin_var}, #{end_var},0);
        }
        "
      else
        if result_var
        "
          {
          VALUE #{begin_var} = Qnil;
          VALUE #{end_var} = Qnil;
          #{to_c tree[1], begin_var};
          #{to_c tree[2], end_var};
          
          #{result_var} = rb_range_new(#{begin_var}, #{end_var},0)
          }
        "
        else
        "rb_range_new(#{to_c tree[1]}, #{to_c tree[2]},0)"
        end
      end
    end
    
  end
end
