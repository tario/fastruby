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
require "fastruby/getlocals"
require "ruby_parser"
require "inline"

# clean rubyinline cache
system("rm -fr #{ENV["HOME"]}/.ruby_inline/*")

class Object
  def self.fastruby(rubycode, *options_hashes)
    tree = RubyParser.new.parse rubycode

    options_hash = options_hashes.inject{|x,y| x.merge(y)}

    if tree[0] != :defn
      raise ArgumentError, "Only definition of methods are accepted"
    end

    method_name = tree[1]
    args_tree = tree[2]

    hashname = "$hash" + rand(1000000).to_s

    hash = Hash.new

    locals = Set.new
    locals << :self

    FastRuby::GetLocalsProcessor.get_locals(RubyParser.new.parse(rubycode)).each do |local|
      locals << local
    end

    hash.instance_eval{@tree = tree}
    hash.instance_eval{@locals = locals}
    self_ = self
    hash.instance_eval{@klass = self_}
    hash.instance_eval{@options = options_hash}

    class_eval do
      class << self
        include FastRuby::BuilderModule
      end
    end

    self_.method_tree[method_name] = tree
    self_.method_locals[method_name] = locals
    self_.method_options[method_name] = options_hash

    def hash.build(key, mname)
      @klass.build(key, @tree, mname, @locals, @options)
    end

    eval("#{hashname} = hash")

    value_cast = ( ["VALUE"]*args_tree.size ).join(",")

    main_signature_argument = args_tree[1..-1].first || "self"

    strmethodargs = ""
    strmethodargs_class = (["self"] + args_tree[1..-1]).map{|arg| "CLASS_OF(#{arg.to_s})"}.join(",")

    if args_tree.size > 1
      strmethodargs = "self,#{args_tree[1..-1].map(&:to_s).join(",") }"
    else
      strmethodargs = "self"
    end

    strmethod_signature = (["self"] + args_tree[1..-1]).map { |arg|
      "sprintf(method_name+strlen(method_name), \"%lu\", CLASS_OF(#{arg}));\n"
    }.join

    c_code = "VALUE #{method_name}( #{args_tree[1..-1].map{|arg| "VALUE #{arg}" }.join(",") }  ) {
      VALUE method_hash = (VALUE)#{hash.internal_value};
      VALUE klass = (VALUE)#{self.internal_value};

      char method_name[0x100];

      method_name[0] = '_';
      method_name[1] = 0;

      sprintf(method_name+1, \"#{method_name}\");
      #{strmethod_signature}

      NODE* body;
      ID id;

      id = rb_intern(method_name);
      body = rb_method_node(klass,id);

      if (body == 0) {
        VALUE argv_class[] = {#{strmethodargs_class} };
        VALUE signature = rb_ary_new4(#{args_tree.size},argv_class);

        rb_funcall(method_hash, #{:build.to_i}, 2, signature, rb_str_new2(method_name));
        body = rb_method_node(klass,id);
      }

        if (nd_type(body) == NODE_CFUNC) {
          int argc = body->nd_argc;

          if (argc == #{args_tree.size-1}) {
            return ((VALUE(*)(#{value_cast}))body->nd_cfnc)(#{strmethodargs});
          } else if (argc == -1) {
            VALUE argv[] = {#{args_tree[1..-1].map(&:to_s).join(",")} };
            return ((VALUE(*)(int,VALUE*,VALUE))body->nd_cfnc)(#{args_tree.size-1},argv,self);
          } else if (argc == -2) {
            VALUE argv[] = {#{args_tree[1..-1].map(&:to_s).join(",")} };
            return ((VALUE(*)(VALUE,VALUE))body->nd_cfnc)(self, rb_ary_new4(#{args_tree.size-1},argv));
          } else {
            rb_raise(rb_eArgError, \"wrong number of arguments (#{args_tree.size-1} for %d)\", argc);
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

