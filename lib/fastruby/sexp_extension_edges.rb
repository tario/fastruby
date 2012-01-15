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
  class FastRubySexp
    class Edges
      def initialize(frbsexp)
        @frbsexp = frbsexp
      end

      def each(&blk)
        node_type = @frbsexp.node_type

        @frbsexp.each do|st|
          next unless FastRubySexp === st
          st.edges.each(&blk)
        end

        if respond_to? "edges_#{node_type}"
          send("edges_#{node_type}", &blk)
        end
      end

      def edges_or(&blk)
        (1..@frbsexp.size-2).each do |i|
          blk.call(@frbsexp[i],@frbsexp[i+1].first_tree)
        end

        blk.call(@frbsexp[-1],@frbsexp)
      end
      alias edges_and edges_or

      def edges_case(&blk)
        variable_tree = @frbsexp[1]

        #require "pry";binding.pry

        blk.call(variable_tree,@frbsexp[2][1][1].first_tree)
        
        @frbsexp[2..-2].each do |st|
          array_tree = st[1]
          (1..array_tree.size-2).each do |i|
            blk.call(array_tree[i],array_tree[i+1])
          end

          if st[2]
            array_tree[1..-1].each do |st2|
              blk.call(st2,st[2].first_tree)  
            end
            blk.call(st[2],@frbsexp)
          end
        end

        (3..@frbsexp.size-2).each do |i|
          blk.call(@frbsexp[i-1][1][-1], @frbsexp[i][1][1].first_tree)
        end

        if @frbsexp[-1]
          blk.call(@frbsexp[-2][1][-1], @frbsexp[-1].first_tree)
          blk.call(@frbsexp[-1], @frbsexp)
        else
          blk.call(@frbsexp[-2][1][-1], @frbsexp)
        end
      end
  
      def edges_if(&blk)
        if @frbsexp[2]
          blk.call(@frbsexp[1],@frbsexp[2].first_tree)
          blk.call(@frbsexp[2],@frbsexp)
        end

        if @frbsexp[3]
          blk.call(@frbsexp[3],@frbsexp)
          blk.call(@frbsexp[1],@frbsexp[3].first_tree)
        end

        unless @frbsexp[2] and @frbsexp[3]
          blk.call(@frbsexp[1],@frbsexp)
        end     
      end

      def edges_scope(&blk)
        blk.call(@frbsexp[1], @frbsexp)
      end

      def edges_while(&blk)
        if @frbsexp[2]
          blk.call(@frbsexp[1], @frbsexp[2].first_tree)
          blk.call(@frbsexp[2], @frbsexp[1].first_tree)
          @frbsexp[2].find_break do |subtree|
            blk.call(subtree, @frbsexp)
          end
        end

        blk.call(@frbsexp[1], @frbsexp)
      end

      alias edges_until edges_while

      def edges_block(&blk)
        (2..@frbsexp.size-1).each do |i|
          blk.call(@frbsexp[i-1], @frbsexp[i].first_tree)
        end
        blk.call(@frbsexp.last, @frbsexp)
      end

      def edges_call(&blk)
        args_tree = @frbsexp[3]

        (2..args_tree.size-1).each do |i|
          blk.call(args_tree[i-1], args_tree[i])
        end

        recv_tree = @frbsexp[1]
        
        if recv_tree
          if args_tree.size > 1
            blk.call(recv_tree, args_tree[1])
          end
        end

        if args_tree.size > 1
          blk.call(args_tree.last, @frbsexp)
        end
      end

      def self.do_nothing_for(*nodename)
        nodename.each do |nn|
          define_method("edges_#{nn}") do
          end
        end
      end

      do_nothing_for(:nil,:lit,:break)
    end
  end
end

