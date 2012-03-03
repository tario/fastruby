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
  class Inferencer
    attr_accessor :infer_self
    attr_accessor :infer_lvar_map
    
    define_infer_for(:lvar) do |tree|
      next [] unless @infer_lvar_map
      
      [@infer_lvar_map[tree[1]]] || []
    end
    
    define_infer_for(:self) do |tree|
      next [] unless @infer_self
      
      [@infer_self] || []
    end
  end
end
