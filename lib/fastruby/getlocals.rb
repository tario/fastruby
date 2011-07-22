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
require "rubygems"
require "sexp_processor"
require "set"

module FastRuby
  class GetLocalsProcessor < SexpProcessor

    attr_reader :locals

    def initialize
      super()
      self.require_empty = false
      @locals = Set.new
    end

    def process_lasgn(tree)
       @locals << tree[1]
       tree.dup
    end

    def self.get_locals(tree)
      processor = GetLocalsProcessor.new
      processor.process(tree)
      processor.locals
    end
  end
end