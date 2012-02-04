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
    define_method_handler(:inline) { |tree|
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
        next tree unless recvtype.respond_to?(:fastruby_method)

        mobject = recvtype.fastruby_method(method_name)
        
        next tree unless mobject
        
        target_method_tree = mobject.tree
        
        next tree unless target_method_tree
        
        target_method_tree_block = target_method_tree.find_tree(:scope)[1].duplicate
        
        target_method_tree_block.walk_tree do |subtree|
          if subtree.node_type == :lvar or subtree.node_type == :lasgn
            add_local subtree[1]
          end
        end
        
        target_method_tree_args = target_method_tree[2]
        
        newblock = fs(:block)
        
        (1..args_tree.size-1).each do |i|
          itype = infer_type(args_tree[i])

          self.extra_inferences[target_method_tree_args[i]] = itype if itype
          newblock << s(:lasgn, target_method_tree_args[i], args_tree[i])
        end
        
        target_method_tree_block[1..-1].each do |subtree|
          newblock << subtree
        end
        
        newblock
      else
        # nothing to do, we don't know what is the method
        tree
      end
    }.condition{|tree| tree.node_type == :call}
  end
end
