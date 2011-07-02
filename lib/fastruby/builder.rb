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
require "fastruby/translator"

module FastRuby
  class Builder
    def self.build(signature, tree)
      context = FastRuby::Context.new

      args_tree = tree[2]
      firstarg = args_tree[1]

      # create random method name
      mname = "mname" + rand(10000000000).to_s
      context.alt_method_name = mname
      context.infer_lvar_map[firstarg] = signature

      c_code = context.to_c(tree)

      inline :C  do |builder|
        print c_code,"\n"
        builder.include "<node.h>"
        builder.c c_code
      end

      instance_method(mname)
    end
  end
end
