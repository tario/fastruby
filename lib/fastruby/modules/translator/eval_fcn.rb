=begin

This file is part of the fastruby project, http://github.com/tario/fastruby

Copyright (c) 2012 Roberto Dario Seminara <robertodarioseminara@gmail.com>

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
  class Context
    define_method_handler(:to_c, :priority => 1000) { |tree, result_var=nil|
      @has_yield = true
      unless result_var
        inline_block "{
          return Qnil;
        }"
      else
        "{
          #{to_c tree[3][1], "last_expression"};
          rb_funcall(#{literal_value FastRuby::Method}, #{intern_num :build_block}, 2, last_expression, #{literal_value @locals_struct});
          VALUE ___block_args[4];

          VALUE (*___func) (int, VALUE*, VALUE, VALUE);
          ___func = (void*)( NUM2PTR(rb_gvar_get((struct global_entry*)#{global_entry(:$last_eval_block)})) );
          #{result_var} = ___func(0,___block_args,(VALUE)plocals,(VALUE)pframe);
        }"
      end
    }.condition { |tree, result_var=nil|
      if tree.node_type == :call
        tree[2] == :eval
      else
        false
      end
    }

  end
end
