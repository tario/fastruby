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
    attr_accessor :infer_lvar_map
    attr_accessor :infer_self
    attr_reader :extra_locals
    attr_reader :extra_inferences
    attr_reader :inlined_methods
    
    def initialize
      @extra_locals = Set.new
      @extra_inferences = Hash.new
      @inlined_methods = Array.new
    end
    
    define_method_handler(:inline, :priority => -1000) do |tree|
      FastRubySexp.from_sexp(tree)
    end
    
    Dir.glob(FastRuby.fastruby_load_path + "/fastruby/inliner/modules/**/*.rb").each do |path|
      require path
    end
    
    def add_local(local)
      @extra_locals << local
    end
    
    def infer_type(recv)
      if recv[0] == :call
        if recv[2] == :infer
          eval(recv[3].last.last.to_s)
        end
      elsif recv[0] == :lvar
        @infer_lvar_map[recv[1]]
      elsif recv[0] == :self
        @infer_self
      elsif recv[0] == :str or recv[0] == :lit
        recv[1].class
      else
        nil
      end
    end

  end
end
