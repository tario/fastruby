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
    
    class BlockProcessing
      def initialize(inlined_name, break_inlined_name)
        @inlined_name = inlined_name
        @break_inlined_name = break_inlined_name
      end
      
      define_method_handler(:process, :priority => -100) { |tree|
        tree.map {|subtree| process subtree}
      }

      define_method_handler(:process, :priority => 1000) { |tree|
        tree
      }.condition{|tree| not tree.respond_to?(:node_type) }

      define_method_handler(:process) { |tree|
        if tree[1]
          fs(:call, nil, :_throw, fs(:arglist, fs(:lit,@inlined_name.to_sym), process(tree[1])))
        else
          fs(:call, nil, :_throw, fs(:arglist, fs(:lit,@inlined_name.to_sym), fs(:nil)))
        end
      }.condition{|tree| tree.node_type == :next}

      define_method_handler(:process) { |tree|
        if tree[1]
          fs(:call, nil, :_throw, fs(:arglist, fs(:lit,@break_inlined_name.to_sym), process(tree[1])))
        else
          fs(:call, nil, :_throw, fs(:arglist, fs(:lit,@break_inlined_name.to_sym), fs(:nil)))
        end
      }.condition{|tree| tree.node_type == :break and @break_inlined_name}
      
      define_method_handler(:process) { |tree|
        fs(:call, nil, :_loop, fs(:arglist, fs(:lit,@inlined_name.to_sym)))
      }.condition{|tree| tree.node_type == :redo}

      define_method_handler(:process) { |tree|
        if tree[3]
          fs(:iter, process(tree[1]), tree[2], tree[3].duplicate)
        else
          fs(:iter, process(tree[1]), tree[2])
        end
      }.condition{|tree| tree.node_type == :iter}
    end
    
    if "1".respond_to?(:ord)
      def inline_local_name(method_name, local_name)
        "__inlined_#{method_name.to_s.gsub("_x_", "_x__x_").gsub(/\W/){|x| "_x_#{x.ord}" }}_#{local_name}".to_sym
      end
    else
      def inline_local_name(method_name, local_name)
        "__inlined_#{method_name.to_s.gsub("_x_", "_x__x_").gsub(/\W/){|x| "_x_#{x[0]}" }}_#{local_name}".to_sym
      end
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
        end
      end
      
      tree
    end
    
    def catch_block(name,tree)
      fs(:block,fs(:iter, fs(:call, nil, :_catch, fs(:arglist, fs(:lit,name.to_sym))),nil,tree))
    end
    
    def method_tree_to_inlined_block(mobject, call_tree, method_name, block_args_tree = nil, block_tree = nil)
        args_tree = call_tree[3]
        recv_tree = call_tree[1] || fs(:self)
        
        target_method_tree = mobject.tree 
        
        @method_index = (@method_index || 0) + 1
        
        prefix = method_name.to_s + "_" + @method_index.to_s
        target_method_tree_block = add_prefix(target_method_tree.find_tree(:scope)[1], prefix)
        
        if target_method_tree_block.find_tree(:return)
          inlined_name = inline_local_name(method_name, "main_return_tagname")
          target_method_tree_block = catch_block(inlined_name,target_method_tree_block)
          
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
          inlined_name = inline_local_name(prefix, target_method_tree_args[i])
          newblock << fs(:lasgn, inlined_name, recursive_inline(args_tree[i].duplicate))
        end
        
        inlined_name = inline_local_name(prefix, :self)
        newblock << fs(:lasgn, inlined_name, recv_tree.duplicate)
        
        return nil if target_method_tree_block.find_tree(:return)

        break_tag = nil
        
        if block_tree
          block_tree = recursive_inline(block_tree)
          if block_tree.find_tree(:break) # FIXME: discard nested iter calls on finding
            break_tag =  inline_local_name(prefix, "__break_tag")
          end
        end
         
        block_num = 0
        
        target_method_tree_block.walk_tree do |subtree|
          if subtree.node_type == :call
            if subtree[1] == nil
              if subtree[2] == :block_given?
                subtree[0..-1] = block_tree ? fs(:true) : fs(:false)
              else
                subtree[1] = recv_tree.duplicate
              end
            end
          end
          if subtree.node_type == :self
            subtree[0] = :lvar
            subtree[1] = inline_local_name(prefix, :self)
          end
          if subtree.node_type == :yield
            if block_tree
              # inline yield
              yield_call_args = subtree.duplicate
              
              subtree[0..-1] = fs(:block)
              
              if block_args_tree
                return nil if yield_call_args[1..-1].find{|x| x.node_type == :splat}
                if block_args_tree.node_type == :masgn
                  return nil if block_args_tree[1].size != yield_call_args.size
                  return nil if block_args_tree[1][1..-1].find{|x| x.node_type == :splat}
              
                  (1..yield_call_args.size-1).each do |i|
                    inlined_name = block_args_tree[1][i][1]
                    subtree << fs(:lasgn, inlined_name, yield_call_args[i])
                  end
                else
                  return nil if 2 != yield_call_args.size

                  inlined_name = block_args_tree[1]
                  subtree << fs(:lasgn, inlined_name, yield_call_args[1])
                end
              else
                return nil if yield_call_args.size > 1
              end
              
              if block_tree.find_tree(:next) or block_tree.find_tree(:redo) or break_tag
                inlined_name = inline_local_name(prefix, "block_block_#{block_num}")
                block_num = block_num + 1
                
                alt_block_tree = BlockProcessing.new(inlined_name, break_tag).process(block_tree)
                alt_block_tree = catch_block(inlined_name,alt_block_tree)
              else
                alt_block_tree = block_tree.duplicate
              end
              subtree << alt_block_tree
            else
              subtree[0..-1] = fs(:call, fs(:nil), :raise, fs(:arglist, fs(:const, :LocalJumpError), fs(:str, "no block given")))
            end
          end
        end
        
        @inlined_methods << mobject
        
        if break_tag
          inner_block = fs(:block)
          target_method_tree_block[1..-1].each do |subtree|
            inner_block << subtree
          end
          
          newblock << catch_block(break_tag,inner_block)
        else
          target_method_tree_block[1..-1].each do |subtree|
            newblock << subtree
          end
        end
        newblock
    end

    def inline_subtree(tree)
      ret_tree = fs(:iter)
      ret_tree << tree[1].duplicate
        
      tree[2..-1].each do |subtree|
        ret_tree << inline(subtree)
      end

      ret_tree
    end
    
    define_method_handler(:inline) { |tree|
        call_tree = tree[1]
        recv_tree = call_tree[1] || fs(:self)
        method_name = call_tree[2]
        args_tree = call_tree[3]
        block_tree = tree[3] || fs(:nil)
        block_args_tree = tree[2]
        
        next inline_subtree(tree) if block_tree.find_tree(:retry)

        recvtype = infer_type(recv_tree)

        if recvtype
          # search the tree of target method
          mobject = method_obj_or_gtfo(recvtype,method_name)
  
          next inline_subtree(tree) unless mobject
          next inline_subtree(tree) unless mobject.tree
        
          exit_now = false
          if block_tree.find_tree(:break) or block_tree.find_tree(:return)
            mobject.tree.walk_tree do |subtree|
              if subtree.node_type == :iter
                if subtree.find_tree(:yield)
                  exit_now = true
                  break
                end
              end
            end
          end
          
          next inline_subtree(tree) if exit_now
          
          target_method_tree_args = mobject.tree[2]
          next inline_subtree(tree) if target_method_tree_args.find{|subtree| subtree.to_s =~ /^\*/}

          method_tree_to_inlined_block(mobject, call_tree, method_name, block_args_tree, block_tree) || inline_subtree(tree)
  
        else
          # nothing to do, we don't know what is the method
          inline_subtree(tree)
        end
     }.condition{|tree| tree.node_type == :iter}
    
    define_method_handler(:inline) { |tree|
      next tree if tree.find_tree(:block_pass)
      
      recv_tree = tree[1] || fs(:self)
      method_name = tree[2]
      args_tree = tree[3]
      
      if method_name == :lvar_type
        next tree
      end
      
      recvtype = infer_type(recv_tree)
 
      if recvtype
        # search the tree of target method
        mobject = method_obj_or_gtfo(recvtype,method_name)

        next recursive_inline(tree) unless mobject
        next recursive_inline(tree) unless mobject.tree
        
        exit_now = false
        mobject.tree.walk_tree do |subtree|
          if subtree.node_type == :iter
            if subtree.find_tree(:return)
              exit_now = true
              break
            end
          end
        end
          
        next recursive_inline(tree) if exit_now

        target_method_tree_args = if mobject.tree.node_type == :defn
            mobject.tree[2]
          else
            mobject.tree[3]
          end
          
        next recursive_inline(tree) if target_method_tree_args.find{|subtree| subtree.to_s =~ /^\*/}

        method_tree_to_inlined_block(mobject, tree, method_name) || recursive_inline(tree)

      else
        # nothing to do, we don't know what is the method
        recursive_inline(tree)
      end
    }.condition{|tree| tree.node_type == :call}
  end
end
