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

    define_translator_for(:call, :priority => 100){ |tree, result_var=nil|
      directive_code = directive(tree)

      if result_var
        return "#{result_var} = #{directive_code};\n"
      else
        return directive_code
      end
      
    }.condition{|*x|
      tree = x.first; tree.node_type == :call && directive(tree)
    }

    define_translator_for(:call, :method => :to_c_attrasgn, :arity => 1)
    def to_c_attrasgn(tree)
      to_c_call(tree)
    end
  end
end
