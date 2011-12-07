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
require "fastruby/sexp_extension"

module FastRuby
  class ScopeModeHelper
    def self.get_scope_mode(tree_)
      tree = FastRuby::FastRubySexp.from_sexp(tree_)
      
      impl_tree = tree[3]
      if impl_tree == s(:scope, s(:block, s(:nil)))
        return :linear
      end
      
      first_call_node = impl_tree.find_tree{|st| st.node_type == :call} 
      first_iter_node = impl_tree.find_tree{|st| st.node_type == :iter}
      
      if first_iter_node
        return :dag
      end
      
      if not first_call_node and not first_iter_node
        return :linear
      end
      
      impl_tree.walk_tree do |subtree|
        if subtree.node_type == :block
          (1..subtree.size-2).each do |i|
            call_node = subtree[i].find_tree do |st2|
              st2.node_type == :call
            end
            
            lvar_node = subtree[i+1].find_tree do |st2|
              st2.node_type == :lvar
            end
            
            if call_node and lvar_node
              # read after write, use dag
              return :dag
            end
          end
        end
      end
      
      :linear
    end
  end
end