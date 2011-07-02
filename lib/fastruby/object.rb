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
require "fastruby/builder"
require "ruby_parser"
require "inline"

# clean rubyinline cache
system("rm -fr #{ENV["HOME"]}/.ruby_inline/*")

class Object
  def self.fastruby(rubycode)
    tree = RubyParser.new.parse rubycode

    if tree[0] != :defn
      raise ArgumentError, "Only definition of methods are accepted"
    end

    method_name = tree[1]
    args_tree = tree[2]


    $hash = Hash.new
    $hash.instance_eval{@tree = tree}

    def $hash.build(key)
      FastRuby::Builder.build(key, @tree)
    end

    c_code = "VALUE #{method_name}( #{args_tree[1..-1].map{|arg| "VALUE #{arg}" }.join(",") }  ) {
      VALUE method_hash = rb_gv_get(\"$hash\");
      VALUE method = Qnil;
      VALUE key = rb_obj_class(#{args_tree[1..-1].first});

      if (!st_lookup(RHASH(method_hash)->tbl, key, &method)) {
        method = rb_funcall(method_hash, #{:build.to_i}, 1, key);
        st_insert(RHASH(method_hash)->tbl, key, method);
      }

      if (method != Qnil) {

        struct METHOD {
           VALUE klass, rklass;
           VALUE recv;
           ID id, oid;
           int safe_level;
           NODE *body;
        };

        struct METHOD *data;
        Data_Get_Struct(method, struct METHOD, data);

        if (nd_type(data->body) == NODE_CFUNC) {
          return ((VALUE(*)(VALUE,VALUE))data->body->nd_cfnc)(#{args_tree[1..-1].map(&:to_s).join(",") });
        }
      }

      return Qnil;
    }"

    inline :C  do |builder|
      print c_code,"\n"
      builder.include "<node.h>"
      builder.c c_code
    end
  end
end

