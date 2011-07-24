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
require "rubygems"
require "inline"
require "set"

module FastRuby
  class Context

    attr_accessor :infer_lvar_map
    attr_accessor :alt_method_name
    attr_accessor :locals
    attr_accessor :options
    attr_reader :extra_code

    def initialize
      @infer_lvar_map = Hash.new
      @extra_code = ""
      @on_block = false
      @options = {}
    end

    def on_block
      begin
        @on_block = true
        yield
      ensure
        @on_block = false
      end
    end

    def to_c(tree)
      return "" unless tree
      send("to_c_" + tree[0].to_s, tree);
    end

    def anonymous_function(method)

      name = "anonymous" + rand(10000000).to_s
      extra_code << method.call(name)

      name
    end

    def to_c_iter(tree)

      call_tree = tree[1]
      args_tree = tree[2]
      recv_tree = call_tree[1]

      other_call_tree = call_tree.dup
      other_call_tree[1] = s(:lvar, :arg)

      call_args_tree = call_tree[3]

      caller_code = nil

      str_lvar_initialization = @locals_struct + " *plocals;
                                plocals = (void*)param;"

      if call_args_tree.size > 1

        str_called_code_args = ""
        str_recv = ""
        on_block do
          str_called_code_args = call_args_tree[1..-1].map{ |subtree| to_c subtree }.join(",")
          str_recv = to_c recv_tree
        end

        str_recv = "plocals->self" unless recv_tree

          caller_code = proc { |name| "
            static VALUE #{name}(VALUE param) {
              // call to #{call_tree[2]}

              #{str_lvar_initialization}
              return rb_funcall(#{str_recv}, #{call_tree[2].to_i}, #{call_args_tree.size-1}, #{str_called_code_args});
            }
          "
          }

      else
        str_recv = ""
        on_block do
          str_recv = to_c recv_tree
        end

        str_recv = "plocals->self" unless recv_tree

          caller_code = proc { |name| "
            static VALUE #{name}(VALUE param) {
              // call to #{call_tree[2]}
              #{str_lvar_initialization}
              return rb_funcall(#{str_recv}, #{call_tree[2].to_i}, 0);
            }
          "
          }
      end

      anonymous_impl = tree[3]
      str_impl = ""

      on_block do
        # if impl_tree is a block, implement the last node with a return
        if anonymous_impl
          if anonymous_impl[0] == :block
            str_impl = anonymous_impl[1..-2].map{ |subtree|
              to_c(subtree)
            }.join(";")

            if anonymous_impl[-1][0] != :return
              str_impl = str_impl + ";return (#{to_c(anonymous_impl[-1])});"
            else
              str_impl = str_impl + ";#{to_c(anonymous_impl[-1])};"
            end
          else
            if anonymous_impl[0] != :return
              str_impl = str_impl + ";return (#{to_c(anonymous_impl)});"
            else
              str_impl = str_impl + ";#{to_c(anonymous_impl)};"
            end
          end
        else
          str_impl = "return Qnil;"
        end

      end

      str_lvar_initialization = @locals_struct + " *plocals;
                                plocals = (void*)param;"

      str_arg_initialization = ""

      if not args_tree
        str_arg_initialization = ""
      elsif args_tree.first == :lasgn
        str_arg_initialization = "plocals->#{args_tree[1]} = arg;"
      elsif args_tree.first == :masgn
        arguments = args_tree[1][1..-1].map(&:last)

        (0..arguments.size-1).each do |i|
          str_arg_initialization << "plocals->#{arguments[i]} = rb_ary_entry(arg,#{i});\n"
        end
      end

      str_arg_initialization

      block_code = proc { |name| "
        static VALUE #{name}(VALUE arg, VALUE param) {
          // block for call to #{call_tree[2]}

          #{str_lvar_initialization};
          #{str_arg_initialization}
          #{str_impl}
        }
      "
      }

      "rb_iterate(#{anonymous_function(caller_code)}, (VALUE)&locals, #{anonymous_function(block_code)}, (VALUE)&locals)"
    end

    def to_c_yield(tree)
      if (tree.size == 1)
        "rb_yield(Qnil)"
      else
        "rb_yield_values(#{tree.size-1}, #{tree[1..-1].map{|subtree| to_c subtree}.join(",")} )"
      end
    end

    def to_c_block(tree)
      str = tree[1..-2].map{ |subtree|
        to_c(subtree)
      }.join(";")


#      if tree[-1][0] != :return
 #       str = str + ";return (#{to_c(tree[-1])});"
  #    else
        str = str + ";#{to_c(tree[-1])};"
   #   end

      str
    end

    def to_c_return(tree)
      "return #{to_c(tree[1])};\n"
    end

    def to_c_lit(tree)
      "(VALUE)#{tree[1].internal_value}"
    end

    def to_c_nil(tree)
      "Qnil"
    end

    def to_c_str(tree)
      "(VALUE)#{tree[1].internal_value}"
    end

    def to_c_hash(tree)

      hash_aset_code = ""
      on_block do
        (0..(tree.size-3)/2).each do |i|
          strkey = to_c tree[1 + i * 2]
          strvalue = to_c tree[2 + i * 2]
          hash_aset_code << "rb_hash_aset(hash, #{strkey}, #{strvalue});"
        end
      end

      wrapper_func = proc { |name| "
        static VALUE #{name}(VALUE value_params) {
          #{@locals_struct} *plocals = (void*)value_params;
          VALUE hash = rb_hash_new();
          #{hash_aset_code}
          return hash;
        }
      " }

      anonymous_function(wrapper_func) + "((VALUE)&locals)"
    end

    def to_c_array(tree)
      if tree.size > 1
        strargs = tree[1..-1].map{|subtree| to_c subtree}.join(",")
        "rb_ary_new3(#{tree.size-1}, #{strargs})"
      else
        "rb_ary_new3(0)"
      end
    end

    def to_c_defn(tree)
      method_name = tree[1]
      args_tree = tree[2]

      impl_tree = tree[3][1]

      @locals_struct = "struct {
        #{@locals.map{|l| "VALUE #{l};\n"}.join}
        #{args_tree[1..-1].map{|arg| "VALUE #{arg};\n"}.join}
        }"

      str_impl = ""
      # if impl_tree is a block, implement the last node with a return
      if impl_tree[0] == :block
        str_impl = impl_tree[1..-2].map{ |subtree|
          to_c(subtree)
        }.join(";")

        if impl_tree[-1][0] != :return
          str_impl = str_impl + ";return (#{to_c(impl_tree[-1])});"
        else
          str_impl = str_impl + ";#{to_c(impl_tree[-1])};"
        end
      else
        if impl_tree[0] != :return
          str_impl = str_impl + ";return (#{to_c(impl_tree)});"
        else
          str_impl = str_impl + ";#{to_c(impl_tree)};"
        end
      end

      "VALUE #{@alt_method_name || method_name}( #{args_tree[1..-1].map{|arg| "VALUE #{arg}" }.join(",") }  ) {
        #{@locals_struct} locals;

        #{args_tree[1..-1].map { |arg|
          "locals.#{arg} = #{arg};\n"
        }.join("") }

        locals.self = self;

        \n
        #{str_impl}
      }"
    end

    def to_c_lasgn(tree)
      struct_accessor = @on_block ? "plocals->" : "locals."

      if options[:validate_lvar_types]
        klass = @infer_lvar_map[tree[1]]
        if klass

          verify_type_function = proc { |name| "
            static VALUE #{name}(VALUE arg) {
              if (CLASS_OF(arg)!=#{klass.internal_value}) rb_raise(#{TypeMismatchAssignmentException.internal_value}, \"Illegal assignment at runtime (type mismatch)\");
              return arg;
            }
          "
          }

          "#{struct_accessor}#{tree[1]} = #{anonymous_function(verify_type_function)}(#{to_c tree[2]})"
        else
          "#{struct_accessor}#{tree[1]} = #{to_c tree[2]}"
        end
      else
        "#{struct_accessor}#{tree[1]} = #{to_c tree[2]}"
      end
    end

    def to_c_lvar(tree)
      if @on_block
        "plocals->" + tree[1].to_s
      else
        "locals." + tree[1].to_s
      end
    end

    def to_c_self(tree)
      "self"
    end

    def to_c_call(tree)
      recv = tree[1]
      mname = tree[2]
      args = tree[3]

      if mname == :infer
        return to_c(recv)
      elsif mname == :lvar_type
        lvar_name = args[1][1]
        lvar_type = eval(args[2][1].to_s)

        @infer_lvar_map[lvar_name] = lvar_type
        return ""
      end

      strargs = args[1..-1].map{|arg| to_c arg}.join(",")

      argnum = args.size - 1

      recv = recv || s(:self)

      recvtype = infer_type(recv)

      if recvtype

        address = nil
        mobject = nil

        inference_complete = true
        signature = [recvtype]

        args[1..-1].each do |arg|
          argtype = infer_type(arg)
          if argtype
            signature << argtype
          else
            inference_complete = false
          end
        end

        if recvtype.respond_to? :method_tree and inference_complete
          method_tree = recvtype.method_tree[tree[2]]
          method_locals = recvtype.method_locals[tree[2]]

          if method_tree
            mname = "_" + tree[2].to_s + signature.map(&:internal_value).map(&:to_s).join
            mobject = recvtype.build(signature, method_tree, mname, method_locals, recvtype.method_options[tree[2]])
          else
            mobject = recvtype.instance_method(tree[2])
          end
        else
          mobject = recvtype.instance_method(tree[2])
        end

        address = getaddress(mobject)
        len = getlen(mobject)

        if address then
          if argnum == 0
            wrapper_func = proc { |name| "
              static VALUE #{name}(VALUE recv) {
                // call to #{recvtype}##{mname}
                if (rb_block_given_p()) {
                  // no passing block, recall
                  return rb_funcall(recv, #{tree[2].to_i}, 0);
                } else {
                  return ((VALUE(*)(VALUE))0x#{address.to_s(16)})(recv);
                }
              }
            " }

            anonymous_function(wrapper_func) + "(#{to_c(recv)})"
          else
            value_cast = ( ["VALUE"]*args.size ).join(",")

            wrapper_func = proc { |name| "
              static VALUE #{name}(VALUE recv, #{ (1..argnum).map{|x| "VALUE _arg"+x.to_s }.join(",")} ) {
                // call to #{recvtype}##{mname}
                if (rb_block_given_p()) {
                  // no passing block, recall
                  return rb_funcall(recv, #{tree[2].to_i}, #{argnum}, #{ (1..argnum).map{|x| "_arg"+x.to_s }.join(",")});
                } else {
                  return ((VALUE(*)(#{value_cast}))0x#{address.to_s(16)})(recv, #{ (1..argnum).map{|x| "_arg"+x.to_s }.join(",")});
                }
              }
            " }

            anonymous_function(wrapper_func) + "(#{to_c(recv)}, #{strargs})"
          end
        else

          if argnum == 0
            "rb_funcall(#{to_c recv}, #{tree[2].to_i}, 0)"
          else
            "rb_funcall(#{to_c recv}, #{tree[2].to_i}, #{argnum}, #{strargs} )"
          end
        end

      else
        if argnum == 0
          "rb_funcall(#{to_c recv}, #{tree[2].to_i}, 0)"
        else
          "rb_funcall(#{to_c recv}, #{tree[2].to_i}, #{argnum}, #{strargs} )"
        end
      end
    end

    def to_c_while(tree)
      "while (#{to_c tree[1]}) {
        #{to_c tree[2]};
      }
      "
    end

    def to_c_false(tree)
      "Qfalse"
    end

    def infer_type(recv)
      if recv[0] == :call
        if recv[2] == :infer
          eval(recv[3].last.last.to_s)
        end
      elsif recv[0] == :lvar
        @infer_lvar_map[recv[1]]
      else
        nil
      end
    end

    inline :C  do |builder|
      builder.include "<node.h>"
      builder.c "VALUE getaddress(VALUE method) {
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
            return INT2FIX(data->body->nd_cfnc);
          }

          return Qnil;
      }"

      builder.c "VALUE getlen(VALUE method) {
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
            return INT2FIX(data->body->nd_argc);
          }

          return Qnil;
      }"

    end
  end
end
