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
  class LvarType
    
    
    define_method_handler(:process) {|tree|
        @current_index = (@current_index || 1) + 1
        varname = "lvar_type_tmp_#{@current_index}".to_sym
        
        class_condition = fs("_static{CLASS_OF(_a) == ::#{@infer_lvar_map[tree[1]].to_s}._invariant }", :_a => fs(:lvar,varname))
       fs(:block,
            fs(:lasgn, varname, tree[2]),
            fs(:if, class_condition, fs(:lasgn, tree[1], fs(:lvar, varname.to_sym)), fs('_raise(FastRuby::TypeMismatchAssignmentException, "")') )
            )
      }.condition{|tree| tree && 
        tree.node_type == :lasgn && 
        @infer_lvar_map[tree[1]] }
  end
end
