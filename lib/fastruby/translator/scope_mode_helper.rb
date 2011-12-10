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
      tree.walk_tree do |subtree|
        if subtree.node_type == :iter
          iter_impl = subtree[3]
          
          return :dag if has_local_variable_access?(subtree[3])
          return :dag if subtree[2]

          if iter_impl
            return_node = iter_impl.find_tree{|st2| st2.node_type == :return}

            if return_node
              return :dag
            end
          end
        end
      end
      
      impl_tree.walk_tree do |subtree|
        if subtree.node_type == :block
          first_call_index = subtree.size
          last_read_index = 0
          (1..subtree.size).each do |i|
            first_call_index = i if has_call?(subtree[i]) and i < first_call_index 
            last_read_index = i if has_lvar?(subtree[i]) and i > last_read_index 
            
          end
          
          return :dag if last_read_index > first_call_index
        elsif subtree.node_type == :if
          # condition_tree -> true_tree
          # condition_tree -> false_tree
          condition_tree = subtree[1]
          true_tree = subtree[2]
          false_tree = subtree[3]
          
          if has_call?(condition_tree)
            return :dag if has_lvar?(true_tree)
            return :dag if has_lvar?(false_tree)
          end
        elsif subtree.node_type == :for
          return :dag
        else
          subtrees = subtree.select{|st2| st2.instance_of? FastRuby::FastRubySexp}
      	  if subtrees.size > 1
            if has_lvar?(*subtrees) and has_call?(*subtrees)
              return :dag
            end
          end
        end
      end
      
      :linear
    end
    
private
    def has_call?(*trees)
      trees.each do |tree|
        return false unless tree.kind_of? FastRuby::FastRubySexp
        
        tree.walk_tree do |subtree|
          if subtree.node_type == :call
            return true
          end
        end
      end
      
      false
    end
    def has_lvar?(*trees)
      trees.each do |tree|
        return false unless tree.kind_of? FastRuby::FastRubySexp

        tree.walk_tree do |subtree|
          if subtree.node_type == :lvar or 
            subtree.node_type == :self or
            subtree.node_type == :yield
            return true
          end
          
          if subtree.node_type == :call
            if subtree[1] == nil
              return true
            end
          end
        end
      end
      
      false
    end
    def has_local_variable_access?(*trees) 
      trees.each do |tree|
        return false unless tree.kind_of? FastRuby::FastRubySexp

        tree.walk_tree do |subtree|
          if subtree.node_type == :lvar or 
            subtree.node_type == :self or 
            subtree.node_type == :yield or
            subtree.node_type == :return or 
            subtree.node_type == :lasgn
            return true
          end
          
          if subtree.node_type == :call
            if subtree[1] == nil
              return true
            end
          end
        end
      end
      false
    end 
  end
end