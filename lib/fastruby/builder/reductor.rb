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
require "fastruby/modules"

module FastRuby
  class Reductor
    def self.reduce_for(ntype, options = {}, &blk)
      define_method_handler(:reduce, options, &blk).condition{|tree| tree.respond_to?(:node_type) && tree.node_type == ntype}
    end
    
    def call(*args)
      reduce *args
    end
    
    define_method_handler(:reduce, :priority => -1000) do |tree|
      FastRubySexp.from_sexp(tree)
    end
    
    FastRuby::Modules.load_all("reductor")
  end
end
