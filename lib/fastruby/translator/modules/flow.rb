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
  module FlowControlTranslator
    
    register_translator_module self
    
    def to_c_case(tree)

      tmpvarname = "tmp" + rand(1000000).to_s;
      @repass_var = tmpvarname

      code = tree[2..-2].map{|subtree|

        # this subtree is a when
        subtree[1][1..-1].map{|subsubtree|
          c_calltree = s(:call, nil, :inline_c, s(:arglist, s(:str, tmpvarname), s(:false)))
          calltree = s(:call, subsubtree, :===, s(:arglist, c_calltree))
              "
                if (RTEST(#{to_c_call(calltree)})) {
                   return #{to_c(subtree[2])};
                }

              "
        }.join("\n")

      }.join("\n")

      inline_block "

        VALUE #{tmpvarname} = #{to_c tree[1]};

        #{code};

        return #{to_c tree[-1]};
      "
    end

    def to_c_if(tree, result_variable_ = nil)
      condition_tree = tree[1]
      impl_tree = tree[2]
      else_tree = tree[3]
      
      result_variable = result_variable_ || "last_expression"
      
      code = "
          if (RTEST(#{to_c condition_tree})) {
            #{to_c impl_tree, result_variable};
          }#{else_tree ?
            " else {
            #{to_c else_tree, result_variable};
            }
            " : ""
          }
      "

      if result_variable_
        code
      else
        inline_block code + "; return last_expression;"
      end
    end

    def to_c_for(tree)
      alter_tree = tree.dup
      alter_tree[0] = :iter
      alter_tree[1] = [:call, alter_tree[1], :each, [:arglist]]
      to_c alter_tree
    end

    def to_c_while(tree)
      inline_block("
          while (#{to_c tree[1]}) {
            #{to_c tree[2]};
          }
          return Qnil;
      ")
    end
  end
end
