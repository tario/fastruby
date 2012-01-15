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

    def when_array_to_if(array)
      if array.size == 1
        array[0] || s(:nil)
      else
        first_when_tree = array[0]
        comparers = first_when_tree[1][1..-1]

        condition_tree = s(:or)
        comparers.each do |st|
          condition_tree << s(:call, st, :===, s(:arglist, s(:lvar, :temporal_case_var))) 
        end

        s(:if, condition_tree, first_when_tree[2], when_array_to_if(array[1..-1]) )
      end
    end
    
    def get_scope_mode(tree_)
      tree = FastRuby::FastRubySexp.from_sexp(tree_).transform do |subtree|
        if subtree.node_type == :for
          s(:iter,s(:call, subtree[1],:each, s(:arglist)),subtree[2], subtree[3] )
        elsif subtree.node_type == :case
          ifs = when_array_to_if(subtree[2..-1])

          s(:block, s(:lasgn, :temporal_case_var, subtree[1]), ifs)
        else
          nil
        end
      end

      if tree.node_type == :defn
        args_tree = tree[2]
        impl_tree = tree[3]
      elsif tree.node_type == :defs
        args_tree = tree[3]
        impl_tree = tree[4]
      end

      graph = impl_tree.to_graph

      args_tree[1..-1].each do |subtree|
        return :dag if subtree.to_s =~ /^\&/
      end

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
        elsif subtree.node_type == :block_pass
          return :dag
        end
      end

      impl_tree.walk_tree do |subtree|
        graph.each_path_from(subtree) do |path|
          # verify path prohibitive for :linear scope (local variable read after call)
          has_call = false
          writes = Set.new

          path.each do |st2|
            if st2.node_type == :call
              writes.clear
              has_call = true
            elsif st2.node_type == :lasgn
              writes << st2[1] # record local writes
            elsif st2.node_type == :lvar or st2.node_type == :self or 
                  st2.node_type == :return or st2.node_type == :yield

              if has_call
                if writes.include? st2[1]
                  # no problem
                else
                  # read after call, the scope of this function must be implemented on heap
                  return :dag
                end
              end
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
          if subtree.node_type == :call or subtree.node_type == :when
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
