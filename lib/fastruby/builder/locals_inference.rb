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
  class LocalsInference
    define_method_handler(:inline, :priority => -1000) do |tree|
      FastRubySexp.from_sexp(tree)
    end
    
    def self.define_process_for(node_type, &blk)
      define_method_handler(:process, &blk).condition{|tree| tree.node_type == node_type}
    end
    
    def call(tree)
      if tree.find_tree{|subtree| subtree.node_type == :lvar && @infer_lvar_map[subtree[1]]}
        process tree
      else      
        tree
      end
    end
    
    FastRuby::Modules.load_all("locals_inference")
  end
end