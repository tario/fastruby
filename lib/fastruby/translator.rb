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
require "rubygems"

module FastRuby
  class Context

    def to_c(tree)
      send("to_c_" + tree[0].to_s, tree);
    end

    def to_c_block(tree)
      tree[1..-1].map{ |subtree|
        to_c(subtree)
      }.join(";")
    end

    def to_c_return(tree)
      "return #{to_c(tree[1])};\n"
    end

    def to_c_lit(tree)
      tree[1].to_s
    end

    def to_c_defn(tree)
      method_name = tree[1]
      "long #{method_name}() {
        #{to_c tree[3][1]}
      }"
    end
  end
end
