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
  class FastRubySexp < Array
    alias node_type first
    
    def map
      sexp = FastRubySexp.new
      self.each do |subtree|
        sexp << yield(subtree)
      end
      sexp
    end
    
    def walk_tree(&block)
      each do |subtree|
        if subtree.instance_of? FastRubySexp
          subtree.walk_tree(&block)
        end
      end
      block.call(self)
    end
    
    def find_tree(ndtype = nil)
      walk_tree do |subtree|
        if (not block_given?) || yield(subtree)
          if (not ndtype) || ndtype == subtree.node_type
            return subtree
          end
        end
      end
      
      return nil
    end
  end
end
