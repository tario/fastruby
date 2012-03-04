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
  class InferenceUpdater
    class AddInfer
      attr_accessor :variable_hash
      
      define_method_handler(:process, :priority => 1) {|tree|
          tree        
        }.condition{|tree| (tree.node_type == :iter and tree[1][2] == :_static) or (tree.node_type == :call and tree[2] == :infer) }
        
      define_method_handler(:process, :priority => -1) {|tree|
          tree.map &method(:process)
        }.condition{|tree| tree.respond_to?(:node_type) }

      define_method_handler(:process, :priority => 1) {|tree|
          tree
        }.condition{|tree| not tree.respond_to?(:node_type) }

      define_method_handler(:process) {|tree|
          fs(:call, tree, :infer, fs(:arglist, fs(:const, variable_hash[tree[1]].to_s.to_sym)))
        }.condition{|tree| tree.node_type == :lvar and variable_hash[tree[1]] and variable_hash[tree[1]] != :dynamic}

    end
    
    def initialize(inferencer)
      @inferencer = inferencer
    end
    
    def call(tree)
      variable_hash = Hash.new
      
      # search variable assignments
      tree.walk_tree do |subtree|
        if subtree.node_type == :lasgn and subtree[2]
          types = @inferencer.infer(subtree[2])
          lname = subtree[1]
          if types.size == 1
            if variable_hash[lname]
              if variable_hash[lname] != types.first
                variable_hash[lname] = :dynamic
              end
            else
              variable_hash[lname] = types.first
            end
          elsif types.size == 0
            variable_hash[lname] = :dynamic
          end 
        end
      end
      
      add_infer = AddInfer.new
      add_infer.variable_hash = variable_hash
      
      add_infer.process(tree)
    end
  end
end