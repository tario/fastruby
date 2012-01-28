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
  class Reductor
    def when_array_to_if(array, temporal_var_name)
      if array.size == 1
        array[0] || fs(:nil)
      else
        first_when_tree = array[0]
        comparers = first_when_tree[1][1..-1]

        condition_tree = fs(:or)
        comparers.each do |st|
          condition_tree << fs(:call, st, :===, fs(:arglist, fs(:lvar, temporal_var_name))) 
        end

        fs(:if, condition_tree, first_when_tree[2], when_array_to_if(array[1..-1], temporal_var_name) )
      end
    end
        
    reduce_for(:case) do |tree|
      temporal_var_name = "temporal_case_var_#{rand(1000000000)}".to_sym
      ifs = when_array_to_if(tree[2..-1], temporal_var_name)
      fs(:block, fs(:lasgn, temporal_var_name, tree[1]), ifs)
    end
  end
end
