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
    def inline_local_name(method_name, local_name)
      "__inlined_#{method_name}_#{local_name}".to_sym
    end
    
    def method_obj_or_gtfo(klass, method_name)
      return nil unless klass.respond_to?(:fastruby_method)
      klass.fastruby_method(method_name)
    end
    
    def add_prefix(tree, prefix)
      tree = tree.duplicate
      tree.walk_tree do |subtree|
        if subtree.node_type == :lvar or subtree.node_type == :lasgn
          subtree[1] = inline_local_name(prefix, subtree[1])
          add_local subtree[1]
        end
      end
      
      tree
    end
    
    def method_tree_to_inlined_block(mobject, call_tree, method_name, block_args_tree = nil, block_tree = nil)
        args_tree = call_tree[3]
        recv_tree = call_tree[1] || fs(:self)
        
        target_method_tree = mobject.tree 
        
        target_method_tree_block = add_prefix(target_method_tree.find_tree(:scope)[1], method_name)
        
        if target_method_tree_block.find_tree(:return)
          inlined_name = inline_local_name(method_name, "main_return_tagname")
          target_method_tree_block = fs(:block,fs(:iter, fs(:call, nil, :_catch, fs(:arglist, fs(:lit,inlined_name.to_sym))),nil,target_method_tree_block))
          
          target_method_tree_block.walk_tree do |subtree|
            if subtree[0] == :return
              if subtree[1]
                subtree[0..-1] = fs(:call, nil, :_throw, fs(:arglist, fs(:lit,inlined_name.to_sym), subtree[1]))
              else
                subtree[0..-1] = fs(:call, nil, :_throw, fs(:arglist, fs(:lit,inlined_name.to_sym), fs(:nil)))
              end
            end
          end
        end
        
        target_method_tree_args = target_method_tree[2]

        newblock = fs(:block)
        
        (1..args_tree.size-1).each do |i|
          itype = infer_type(args_tree[i])
          inlined_name = inline_local_name(method_name, target_method_tree_args[i])

          add_local inlined_name

          self.extra_inferences[inlined_name] = itype if itype
          newblock << fs(:lasgn, inlined_name, args_tree[i].duplicate)
        end
        
        inlined_name = inline_local_name(method_name, :self)
        add_local inlined_name
        newblock << fs(:lasgn, inlined_name, recv_tree.duplicate)
        
        return nil if target_method_tree_block.find_tree(:return)
        
        target_method_tree_block.walk_tree do |subtree|
          if subtree.node_type == :call
            if subtree[1] == nil
              if subtree[2] == :block_given?
                subtree[0..-1] = fs(:false)
              else
                subtree[1] = recv_tree.duplicate
              end
            end
          end
          if subtree.node_type == :self
            subtree[0] = :lvar
            subtree[1] = inline_local_name(method_name, :self)
          end
          if subtree.node_type == :yield
            if block_tree
              # inline yield
              yield_call_args = subtree.duplicate
              
              subtree[0..-1] = fs(:block)
              
              if block_args_tree
                return nil if yield_call_args[1..-1].find{|x| x.node_type == :splat}
                if block_args_tree.node_type == :massgn
                  return nil if block_args_tree[1].size != yield_call_args.size
                  return nil if block_args_tree[1][1..-1].find{|x| x.node_type == :splat}
              
                  (1..yield_call_args.size-1).each do |i|
                    inlined_name = block_args_tree[1][i][1]
                    add_local inlined_name
                    subtree << fs(:lasgn, inlined_name, add_prefix(yield_call_args[i],method_name))
                  end
                else
                  return nil if 2 != yield_call_args.size

                  inlined_name = block_args_tree[1]
                  add_local inlined_name
                  subtree << fs(:lasgn, inlined_name, add_prefix(yield_call_args[1],method_name))
                end
              else
                return nil if yield_call_args.size > 1
              end
              
              subtree << block_tree
            else
              subtree[0..-1] = fs(:call, fs(:nil), :raise, fs(:arglist, fs(:const, :LocalJumpError), fs(:str, "no block given")))
            end
          end
        end
        
        @inlined_methods << mobject
        target_method_tree_block[1..-1].each do |subtree|
          newblock << subtree
        end
        newblock
    end
    
    define_method_handler(:inline) { |tree|
        ret_tree = fs(:iter)
        ret_tree << tree[1].duplicate
        
        call_tree = tree[1]
        recv_tree = call_tree[1] || fs(:self)
        method_name = call_tree[2]
        args_tree = call_tree[3]
        block_tree = tree[3] || fs(:nil)
        block_args_tree = tree[2]
        
        tree[2..-1].each do |subtree|
          ret_tree << inline(subtree)
        end
        
        next ret_tree if block_tree.find_tree(:break) or block_tree.find_tree(:redo) or block_tree.find_tree(:next) or block_tree.find_tree(:retry)

        recvtype = infer_type(recv_tree)

        if recvtype
          # search the tree of target method
          mobject = method_obj_or_gtfo(recvtype,method_name)
  
          next tree unless mobject
          next tree unless mobject.tree
          next tree if mobject.tree.find_tree(:iter)
          target_method_tree_args = mobject.tree[2]
          next tree if target_method_tree_args.find{|subtree| subtree.to_s =~ /^\*/}

          method_tree_to_inlined_block(mobject, call_tree, method_name, block_args_tree, block_tree) || ret_tree
  
        else
          # nothing to do, we don't know what is the method
          ret_tree
        end
     }.condition{|tree| tree.node_type == :iter}
    
    define_method_handler(:inline) { |tree|
      
      next tree if tree.find_tree(:block_pass)
      
      recv_tree = tree[1] || fs(:self)
      method_name = tree[2]
      args_tree = tree[3]
      
      if method_name == :lvar_type
        lvar_name = args_tree[1][1] || args_tree[1][2]
        lvar_type = eval(args_tree[2][1].to_s)

        @infer_lvar_map[lvar_name] = lvar_type
        next tree
      end
      
      recvtype = infer_type(recv_tree)
 
      if recvtype
        # search the tree of target method
        mobject = method_obj_or_gtfo(recvtype,method_name)

        next tree unless mobject
        next tree unless mobject.tree
        next tree if mobject.tree.find_tree(:iter)
        target_method_tree_args = mobject.tree[2]
        next tree if target_method_tree_args.find{|subtree| subtree.to_s =~ /^\*/}

        method_tree_to_inlined_block(mobject, tree, method_name) || tree

      else
        # nothing to do, we don't know what is the method
        tree
      end
    }.condition{|tree| tree.node_type == :call}
  end
end
