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
require "fastruby/inline_extension"

module FastRuby
  module BuilderModule
    def build(signature, method_name)
      tree = self.method_tree[method_name]
      locals = self.method_locals[method_name]
      options = self.method_options[method_name]
      mname = "_" + method_name.to_s + signature.map(&:internal_value).map(&:to_s).join

      context = FastRuby::Context.new
      context.locals = locals
      context.options = options

      args_tree = tree[2]

      # create random method name
      context.alt_method_name = mname

      (1..signature.size).each do |i|
        arg = args_tree[i]
        context.infer_lvar_map[arg] = signature[i]
      end

      c_code = context.to_c(tree)

      inline :C  do |builder|
        print c_code,"\n"
        print context.extra_code,"\n"

        builder.inc << context.extra_code
        builder.include "<node.h>"
        builder.c c_code
      end

      ret = instance_method(mname)

      ret.extend MethodExtent
      ret.yield_signature = context.yield_signature

      ret
    end

    module MethodExtent
      attr_accessor :yield_signature
    end

    def method_tree
      @method_tree = Hash.new unless @method_tree
      @method_tree
    end

    def method_locals
      @method_locals = Hash.new unless @method_locals
      @method_locals
    end

    def method_options
      @method_options = Hash.new unless @method_options
      @method_options
    end

  end
end
