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
  class Context
    define_translator_for(:iter, :arity => 1, :priority => 1) { |*x|
      ret = nil
      tree = x.first
      
      enable_handler_group(:static_call) do
        ret = x.size == 1 ? to_c(tree[3]) : to_c(tree[3], x.last)
      end
      ret
    }.condition{ |*x|
      tree = x.first
      tree.node_type == :iter && tree[1][2] == :_static
    }
    
    define_translator_for(:iter, :arity => 1, :priority => 1) { |*x|
      ret = nil
      tree = x.first
      
      disable_handler_group(:static_call) do
        ret = x.size == 1 ? to_c(tree[3]) : to_c(tree[3], x.last)
      end
      ret
    }.condition{ |*x|
      tree = x.first
      tree.node_type == :iter && tree[1][2] == :_dynamic
    }
    
    handler_scope(:group => :static_call, :priority => 1000) do
      define_translator_for(:call) do |tree, result=nil|
        method_name = tree[2].to_s
        recv_tree = tree[1]
        
        if recv_tree
          if tree[2] == :+
            code = "( ( #{to_c(tree[1])} )+(#{to_c(tree[3][1])}) )"
          else
            raise "invalid static call #{method_name}"
          end
        else
          args = tree[3][1..-1].map(&method(:to_c)).join(",")
          code = "#{method_name}( #{args} )"
        end

        if result
          "#{result} = #{code};"
        else
          code
        end
      end
    end

    define_method_handler(:initialize_to_c){|*x|}.condition do |*x|
      disable_handler_group(:static_call, :to_c); false
    end
  end
end
