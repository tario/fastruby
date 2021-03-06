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
    define_translator_for(:if, :method => :to_c_if)
    def to_c_if(tree, result_variable_ = nil)
      condition_tree = tree[1]
      impl_tree = tree[2]
      else_tree = tree[3]
      
      result_variable = result_variable_ || "last_expression"
      
      infered_value = infer_value(condition_tree)
      unless infered_value
        
        code = proc{"
          {
            VALUE condition_result;
            #{to_c condition_tree, "condition_result"};
            if (RTEST(condition_result)) {
              #{to_c impl_tree, result_variable};
            }#{else_tree ?
              " else {
              #{to_c else_tree, result_variable};
              }
              " : ""
            }
          }
        "}
  
        if result_variable_
          code.call
        else
          inline_block { code.call + "; return last_expression;" }
        end
      else
        if infered_value.value
          to_c(impl_tree, result_variable_)
        else
          if else_tree
            to_c(else_tree, result_variable_)
          else
            to_c(s(:nil), result_variable_)
          end
        end
      end
    end

    define_translator_for(:while, :method => :to_c_while)
    def to_c_while(tree, result_var = nil)
      
      begin_while = "begin_while_"+rand(10000000).to_s
      end_while = "end_while_"+rand(10000000).to_s
      aux_varname = "_aux_" + rand(10000000).to_s
      code = proc{ "
        {
          VALUE while_condition;
          VALUE #{aux_varname};
          
#{begin_while}:
          #{to_c tree[1], "while_condition"};
          if (!RTEST(while_condition)) goto #{end_while}; 
          #{to_c tree[2], aux_varname};
          goto #{begin_while};
#{end_while}:
          
          #{
          if result_var
            "#{result_var} = Qnil;"
          else
            "return Qnil;"
          end
          }
        }
      "}
      
      if result_var
        code.call
      else
        inline_block &code
      end
      
    end
  end
end
