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
require "fastruby/method_extension"
require "ruby_parser"
require "inline"

# clean rubyinline cache
system("rm -fr #{ENV["HOME"]}/.ruby_inline/*")

$top_level_binding = binding

module FastRuby
  def self.encapsulate_tree(tree, method_name)
      generated_tree = tree

      if generated_tree[0] == :scope
        generated_tree = s(:defn, method_name.to_sym, s(:args),
                s(:scope, s(:block, generated_tree[1])))
      elsif generated_tree[0] == :block
        generated_tree = s(:defn, method_name.to_sym, s(:args),
                    s(:scope, generated_tree))
      else
        generated_tree = s(:defn, method_name.to_sym, s(:args),
                    s(:scope, s(:block, generated_tree)))
      end

      generated_tree
  end
end

class Object

  def fastruby(argument, *options_hashes)
    tree = nil

    if argument.instance_of? Sexp
      tree = argument
    elsif argument.instance_of? String
      tree = RubyParser.new.parse(argument)
    else
      raise ArgumentError
    end

    return unless tree

    if tree[0] == :class
      classname = Object.to_class_name tree[1]

      eval("
      class #{classname}
      end
      ", $top_level_binding)

      klass = eval(classname)

      method_name = "_anonymous_" + rand(100000000000).to_s
      $generated_tree = FastRuby.encapsulate_tree(tree[3],method_name)
      $options_hashes = options_hashes

      klass.class_eval do
        class << self
           fastruby $generated_tree, *$options_hashes
        end
      end

      klass.send(method_name)
    else
      method_name = "_anonymous_" + rand(100000000000).to_s
      Object.fastruby(FastRuby.encapsulate_tree(tree,method_name), *options_hashes)
      send(method_name)
    end
  end

  def self.fastruby_defs(*args)
    raise NoMethodError, "not implemented yet"
  end

  def self.fastruby(argument,*options_hashes)

    tree = nil

    if argument.instance_of? Sexp
      tree = argument
    elsif argument.instance_of? String
      tree = RubyParser.new.parse(argument)
    else
      raise ArgumentError
    end

    return unless tree

    if tree.node_type == :defn
      fastruby_defn(tree,*options_hashes)
    else
       method_name = "_anonymous_" + rand(100000000000).to_s
      $generated_tree = FastRuby.encapsulate_tree(tree,method_name)
      $options_hashes = options_hashes

      klass = self
      klass.class_eval do
        class << self
          fastruby_defn($generated_tree,*$options_hashes)
        end
      end

      send(method_name)
    end

  end

  def self.fastruby_defn(tree, *options_hashes)

    options_hash = {:validate_lvar_types => true}
    options_hashes.each do |opt|
      options_hash.merge!(opt)
    end

    if tree[0] == :block
      (1..tree.size-1).each do |i|
        fastruby(tree[i], *options_hashes)
      end

      return
    elsif tree[0] != :defn
      raise ArgumentError, "Only definition of methods are accepted"
    end

    method_name = tree[1]
    args_tree = tree[2]

    hashname = "$hash" + rand(1000000).to_s

    hash = Hash.new

    locals = Set.new
    locals << :self

    FastRuby::GetLocalsProcessor.get_locals(tree).each do |local|
      locals << local
    end

    self_ = self
    hash.instance_eval{@klass = self_}
    hash.instance_eval{@method_name = method_name}

    class_eval do
      class << self
        include FastRuby::BuilderModule
      end
    end

    fastrubym = self_.fastruby_method(method_name)
    fastrubym.tree = tree
    fastrubym.locals = locals
    fastrubym.options = options_hash

    def hash.build(key)
      @klass.build(key, @method_name)
    end

    eval("#{hashname} = hash")

    value_cast = ( ["VALUE"]*(args_tree.size+1) ).join(",")

    main_signature_argument = args_tree[1..-1].first || "self"

    strmethodargs = ""
    strmethodargs_class = (["self"] + args_tree[1..-1]).map{|arg| "CLASS_OF(#{arg.to_s})"}.join(",")

    if args_tree.size > 1
      strmethodargs = "self,block,#{args_tree[1..-1].map(&:to_s).join(",") }"
    else
      strmethodargs = "self,block"
    end

    strmethod_signature = (["self"] + args_tree[1..-1]).map { |arg|
      "sprintf(method_name+strlen(method_name), \"%lu\", CLASS_OF(#{arg}));\n"
    }.join

    c_code = "VALUE #{method_name}(#{args_tree[1..-1].map{|arg| "VALUE #{arg}" }.join(",")}) {
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

        rb_funcall(method_hash, #{:build.to_i}, 1, signature);
        body = rb_method_node(klass,id);
      }

        if (nd_type(body) == NODE_CFUNC) {
          int argc = body->nd_argc;

          VALUE block = Qfalse;

          if (rb_block_given_p()) {
            struct {
              void *block_function_address;
              void *block_function_param;
            } block_struct;

            block_struct.block_function_address = re_yield;
            block_struct.block_function_param = 0;

            block = (VALUE)&block_struct;
          }

          if (argc == #{args_tree.size}) {
            return ((VALUE(*)(#{value_cast}))body->nd_cfnc)(#{strmethodargs});
          } else if (argc == -1) {
            VALUE argv[] = {#{(["block"]+args_tree[1..-1]).map(&:to_s).join(",")} };
            return ((VALUE(*)(int,VALUE*,VALUE))body->nd_cfnc)(#{args_tree.size},argv,self);
          } else if (argc == -2) {
            VALUE argv[] = {#{(["block"]+args_tree[1..-1]).map(&:to_s).join(",")} };
            return ((VALUE(*)(VALUE,VALUE))body->nd_cfnc)(self, rb_ary_new4(#{args_tree.size},argv));
          } else {
            rb_raise(rb_eArgError, \"wrong number of arguments (#{args_tree.size-1} for %d)\", argc);
          }
        }

      return Qnil;
    }"

    inline :C  do |builder|
      builder.include "<node.h>"
      builder.inc << "static VALUE re_yield(int argc, VALUE* argv, VALUE param) {
        return rb_yield_splat(rb_ary_new4(argc,argv));
      }"
      builder.c c_code
    end
  end

  def internal_value
    $refered_from_code_array = Array.new unless $refered_from_code_array
    $refered_from_code_array << self

    internal_value_
  end

  inline :C do |builder|
    builder.c "VALUE internal_value_() {
      return INT2FIX(self);
    }"
  end

  private
      def self.to_class_name(argument)
        if argument.instance_of? Symbol
          argument.to_s
        elsif argument.instance_of? Sexp
          if argument[0] == :colon3
            "::" + to_class_name(argument[1])
          elsif argument[0] == :colon2
            to_class_name(argument[1]) + "::" + to_class_name(argument[2])
          elsif argument[0] == :const
            to_class_name(argument[1])
          end
        end
      end

end

