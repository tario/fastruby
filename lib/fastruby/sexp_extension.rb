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
require "fastruby/fastruby_sexp"
require "ruby_parser"

class Object
  def to_fastruby_sexp
    self
  end
end

module FastRuby
  class FastRubySexp
    class Edges
      def initialize(frbsexp)
        @frbsexp = frbsexp
      end

      def each(&blk)
        node_type = @frbsexp.node_type
        send("edges_#{node_type}", &blk)
      end
  
      def edges_if(&blk)
        @frbsexp[1..-1].each do |subtree|
          if subtree
          subtree.edges.each(&blk)
          end
        end

        if @frbsexp[2]
          blk.call(@frbsexp[1],@frbsexp[2])
          blk.call(@frbsexp[2],@frbsexp)
        end

        if @frbsexp[3]
          blk.call(@frbsexp[3],@frbsexp)
          blk.call(@frbsexp[1],@frbsexp[3])
        end

        unless @frbsexp[2] and @frbsexp[3]
          blk.call(@frbsexp[1],@frbsexp)
        end     
      end

      def edges_scope(&blk)
        @frbsexp[1].edges.each(&blk)
        blk.call(@frbsexp[1], @frbsexp)
      end

      def edges_block(&blk)
        @frbsexp[1..-1].each do |subtree|
          subtree.edges.each(&blk)
        end

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

      do_nothing_for(:nil,:lit)
    end

    def initialize
      super

      @edges = Edges.new(self)
    end

    def self.from_sexp(value)
      ary = FastRuby::FastRubySexp.new
      value.each do |x|
        ary << x.to_fastruby_sexp
      end
      ary
    end

    def self.parse(code)
      from_sexp(RubyParser.new.parse(code))
    end

    def edges
      @edges
    end

    def first_tree
      send("first_tree_#{node_type}")
    end

    def first_tree_call
      recv = self[1]
      if recv
        recv.first_tree
      else
        args_tree = self[3]
        if args_tree.size > 1
          args_tree[1].first_tree
        else
          self
        end
      end
    end

    def first_tree_lvar; self; end
    def first_tree_lit; self; end
  end
end

class Sexp
  def to_fastruby_sexp
    FastRuby::FastRubySexp.from_sexp(self)
  end
end
