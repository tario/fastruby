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

    def to_c_and(tree)
      "(RTEST(#{to_c tree[1]}) && RTEST(#{to_c tree[2]})) ? Qtrue : Qfalse"
    end

    def to_c_or(tree)
      "(RTEST(#{to_c tree[1]}) || RTEST(#{to_c tree[2]})) ? Qtrue : Qfalse"
    end

    def to_c_not(tree)
      "RTEST(#{to_c tree[1]}) ? Qfalse : Qtrue"
    end
    
  end
end
