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

    hashname = "$hash" + rand(1000000).to_s

    hash = Hash.new
    hash.instance_eval{@tree = tree}
    hash.instance_eval{@method_name = method_name.to_s}

    def hash.build(key)
      FastRuby::Builder.build(key, @tree, "_" + @method_name + "_" + key.to_s)
    end

    eval("#{hashname} = hash")

    value_cast = ( ["VALUE"]*args_tree.size ).join(",")

    main_signature_argument = args_tree[1..-1].first || "self"


    strmethodargs = ""
    if args_tree.size > 1
      strmethodargs = "self,#{args_tree[1..-1].map(&:to_s).join(",") }"
    else
      strmethodargs = "self"
    end

    c_code = "VALUE #{method_name}( #{args_tree[1..-1].map{|arg| "VALUE #{arg}" }.join(",") }  ) {
      VALUE method_hash = (VALUE)#{hash.internal_value};
      VALUE method = Qnil;
      VALUE key = rb_obj_class(#{main_signature_argument});

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
          int argc = data->body->nd_argc;

          if (argc == #{args_tree.size-1}) {
            return ((VALUE(*)(#{value_cast}))data->body->nd_cfnc)(#{strmethodargs});
          } else if (argc == -1) {
            VALUE argv[] = {#{args_tree[1..-1].map(&:to_s).join(",")} };
            return ((VALUE(*)(int,VALUE*,VALUE))data->body->nd_cfnc)(#{args_tree.size-1},argv,self);
          } else if (argc == -2) {
            VALUE argv[] = {#{args_tree[1..-1].map(&:to_s).join(",")} };
            return ((VALUE(*)(VALUE,VALUE))data->body->nd_cfnc)(self, rb_ary_new4(#{args_tree.size-1},argv));
          } else {
            rb_raise(rb_eArgError, \"wrong number of arguments (#{args_tree.size-1} for %d)\", argc);
          }
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

  inline :C do |builder|
    builder.c "VALUE internal_value() {
      return INT2FIX(self);
    }"
  end
end

