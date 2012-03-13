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
require "set"
require "sexp"
require "define_method_handler"
 
module FastRuby
  class Inliner
    handler_scope :group => :def, :priority => 1000 do
      define_method_handler(:inline) { |tree|
        disable_handler_group(:def) do
          inline(tree)
        end
      }.condition{|tree| tree.node_type == :defn}
      
      define_method_handler(:inline) { |tree|
        disable_handler_group(:def) do
          inline(tree)
        end
      }.condition{|tree| tree.node_type == :defs}
    end
  end
end
