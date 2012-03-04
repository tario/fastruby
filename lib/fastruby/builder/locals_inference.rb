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
  class LocalsInference
    attr_accessor :infer_self
    attr_accessor :infer_lvar_map
    
    def call(arg)
      if arg.find_tree{|subtree| subtree.node_type == :lvar && @infer_lvar_map[subtree[1]]}
        transform_block = proc do |tree|
          if tree.node_type == :lvar
            next tree unless @infer_lvar_map
            lvar_type = @infer_lvar_map[tree[1]]
            next tree unless lvar_type
            fs(:call, tree, :infer, fs(:arglist, fs(:const, lvar_type.to_s.to_sym)))
          elsif tree.node_type == :iter
            if tree[1][2] == :_static
              tree
            end
          elsif tree.node_type == :call
            if tree[2] == :infer
              tree[1]
            end
          else
            nil
          end
        end
        
        arg.transform &transform_block
      else      
        arg
      end
    end
  end
end