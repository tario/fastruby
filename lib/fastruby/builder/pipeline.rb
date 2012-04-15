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
require "define_method_handler"

module FastRuby
  class Pipeline
    def initialize
      @array = Array.new
    end
    
    def << (object)
      @array << object
    end

    def remove_array(tree)
      if tree.class == Array or tree.class == FastRubySexp
        sexp = FastRubySexp.new
        tree.each do |subtree|
          sexp << remove_array(subtree)
        end
        sexp
      else
        tree
      end
    end
    
    def call(arg)
      
      last_result = arg 
      @array.each do |processor|
        last_result = remove_array processor.call(last_result)
      end
      
      last_result
    end
  end
end
