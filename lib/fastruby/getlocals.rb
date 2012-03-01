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
require "fastruby/fastruby_sexp"

module FastRuby
  class GetLocalsProcessor

    attr_reader :locals

    def initialize
      @locals = Set.new
    end

    def process(tree)
      if tree.node_type == :lasgn
       @locals << tree[1]
      end
      
      if tree[0] == :args

        tree[1..-1].each do |subtree|
          if subtree.instance_of? Symbol
             @locals << subtree.to_s.gsub("*","").gsub("&","").to_sym
          end
        end

        if tree.find{|x| x.to_s[0] == ?&}
          @locals << :__xproc_arguments
        end
      end

      if tree[0] == :block_pass
        @locals << :__xblock_arguments
        @locals << :__x_proc
      end

      tree.select{|subtree| subtree.instance_of? FastRuby::FastRubySexp}.each do |subtree|
        process(subtree)
      end
    end

    def self.get_locals(tree)
      processor = GetLocalsProcessor.new
      processor.process(tree)
      ret_locals = processor.locals
      ret_locals << :self
      ret_locals
    end
  end
end
