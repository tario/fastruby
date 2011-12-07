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
      new.get_scope_mode(tree_)
    end
    
    def get_scope_mode(tree_)
      tree = FastRuby::FastRubySexp.from_sexp(tree_)
      
      impl_tree = tree[3]
      if impl_tree == s(:scope, s(:block, s(:nil)))
        return :linear
      end
      
      first_call_node = impl_tree.find_tree{|st| st.node_type == :call} 
      first_iter_node = impl_tree.find_tree{|st| st.node_type == :iter}

      if not first_call_node and not first_iter_node
        return :linear
      end
      
      tree.walk_tree do |subtree|
        if subtree.node_type == :iter
          iter_impl = subtree[3]
          
          return :dag if has_local_variable_access? subtree

          if iter_impl
            return_node = iter_impl.find_tree{|st2| st2.node_type == :return}

            if return_node
              return :dag
            end
          end
        end
      end
      
      find_call_block = proc do |st2|
         st2.node_type == :call
      end
      find_lvar_block = proc do |st2|
         st2.node_type == :lvar
      end
      
      impl_tree.walk_tree do |subtree|
        if subtree.node_type == :block
          (1..subtree.size-2).each do |i|
            return :dag if has_call?(subtree[i]) and has_lvar?(subtree[i+1])
          end
        elsif subtree.node_type == :while
          call_node_1 = subtree[1].find_tree(&find_call_block)
          call_node_2 = subtree[2].find_tree(&find_call_block)
          lvar_node_1 = subtree[1].find_tree(&find_lvar_block)
          lvar_node_2 = subtree[2].find_tree(&find_lvar_block)
          
          if (call_node_1 or call_node_2) and (lvar_node_1 or lvar_node_2)
            return :dag
          end
        end
      end
      
      :linear
    end
    
private
    def has_call?(tree)
      tree.walk_tree do |subtree|
        if subtree.node_type == :call
          return true
        end
      end
      
      false
    end
    def has_lvar?(tree)
      tree.walk_tree do |subtree|
        if subtree.node_type == :lvar
          return true
        end
      end
      
      false
    end
    def has_local_variable_access?(tree) 
      tree.walk_tree do |subtree|
        if subtree.node_type == :lvar or subtree.node_type == :yield or subtree.node_type == :lasgn
          return true
        end
      end
      
      false
    end 
  end
end