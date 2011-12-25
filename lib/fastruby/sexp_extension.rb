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
  
      def edges_scope(&blk)
        @frbsexp[1].edges.each(&blk)
        blk.call(@frbsexp[1], @frbsexp)
      end

      def edges_block(&blk)
        @frbsexp[1].edges.each(&blk)
        blk.call(@frbsexp[1], @frbsexp)
      end

      def edges_nil
      end
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
  end
end

class Sexp
  def to_fastruby_sexp
    FastRuby::FastRubySexp.from_sexp(self)
  end
end
