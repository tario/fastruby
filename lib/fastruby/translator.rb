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
    attr_reader :extra_code

    def initialize
      @infer_lvar_map = Hash.new
      @locals = Set.new
      @extra_code = ""
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

      recv_tree = tree[1]
      method_name = tree[2]

      caller_code = proc { |name| "
        static VALUE #{name}(VALUE arg) {
          return rb_funcall(arg, #{method_name.to_i}, 0);
        }
      "
      }

      block_code = proc { |name| "
        static VALUE #{name}(VALUE block_arg, VALUE nil) {
          return Qnil;
        }
      "
      }

      "rb_iterate(#{anonymous_function(caller_code)}, #{to_c recv_tree}, #{anonymous_function(block_code)}, Qnil)"
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
      "INT2FIX(#{tree[1].to_s})"
    end

    def to_c_defn(tree)
      method_name = tree[1]
      args_tree = tree[2]

      impl_tree = tree[3][1]

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

      str_locals = @locals.map{|l| "VALUE #{l};"}.join

      "VALUE #{@alt_method_name || method_name}( #{args_tree[1..-1].map{|arg| "VALUE #{arg}" }.join(",") }  ) {
        #{str_locals}
        #{str_impl}
      }"
    end

    def to_c_lasgn(tree)
      @locals << tree[1]
      "#{tree[1]} = #{to_c tree[2]};"
    end

    def to_c_lvar(tree)
      tree[1].to_s
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

          if method_tree
            mname = "_" + tree[2].to_s + signature.map(&:internal_value).map(&:to_s).join
            mobject = recvtype.build(signature, method_tree, mname)
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
            "((VALUE(*)(VALUE))0x#{address.to_s(16)})(#{to_c(recv)})"
          else
             value_cast = ( ["VALUE"]*args.size ).join(",")
            "((VALUE(*)(#{value_cast}))0x#{address.to_s(16)})(#{to_c(recv)}, #{strargs})"
          end
        else

          if argnum == 0
            "rb_funcall(#{to_c tree[1]}, #{tree[2].to_i}, 0)"
          else
            "rb_funcall(#{to_c tree[1]}, #{tree[2].to_i}, #{argnum}, #{strargs} )"
          end
        end

      else
        if argnum == 0
          "rb_funcall(#{to_c tree[1]}, #{tree[2].to_i}, 0)"
        else
          "rb_funcall(#{to_c tree[1]}, #{tree[2].to_i}, #{argnum}, #{strargs} )"
        end
      end
    end

    def to_c_while(tree)
      "while (#{to_c tree[1]}) {
        #{to_c tree[2]}
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
