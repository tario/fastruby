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
  module LogicalOperatorTranslator
    register_translator_module self

    def to_c_and(tree, return_var = nil)
      if return_var
        "
          {
            VALUE op1 = Qnil;
            VALUE op2 = Qnil;
            #{to_c tree[1], "op1"};
            #{to_c tree[2], "op2"};
            #{return_var} = (RTEST(op1) && RTEST(op2)) ? Qtrue : Qfalse;
          }
        "
      else
        "(RTEST(#{to_c tree[1]}) && RTEST(#{to_c tree[2]})) ? Qtrue : Qfalse"
      end
      
    end

    def to_c_or(tree, return_var = nil)
      if return_var
        "
          {
            VALUE op1 = Qnil;
            VALUE op2 = Qnil;
            #{to_c tree[1], "op1"};
            #{to_c tree[2], "op2"};
            #{return_var} = (RTEST(op1) || RTEST(op2)) ? Qtrue : Qfalse;
          }
        "
      else
      "(RTEST(#{to_c tree[1]}) || RTEST(#{to_c tree[2]})) ? Qtrue : Qfalse"
      end
    end

    def to_c_not(tree, return_var = nil)
      if return_var
        "
          {
            VALUE op1 = Qnil;
            #{to_c tree[1], "op1"};
            #{return_var} = (RTEST(op1)) ? Qfalse: Qtrue;
          }
        "
      else
        "RTEST(#{to_c tree[1]}) ? Qfalse : Qtrue"
      end
    end
    
  end
end
