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

module FastRuby
  class Context

    attr_accessor :infer_lvar_map

    def initialize
      @infer_lvar_map = Hash.new
    end

    def to_c(tree)
      send("to_c_" + tree[0].to_s, tree);
    end

    def to_c_block(tree)
      tree[1..-1].map{ |subtree|
        to_c(subtree)
      }.join(";")
    end

    def to_c_return(tree)
      "return #{to_c(tree[1])};\n"
    end

    def to_c_lit(tree)
      tree[1].to_s
    end

    def to_c_defn(tree)
      method_name = tree[1]
      args_tree = tree[2]
      "VALUE #{method_name}( #{args_tree[1..-1].map{|arg| "VALUE #{arg}" }.join(",") }  ) {
        #{to_c tree[3][1]}
      }"
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
      end

      strargs = args[1..-1].map{|arg| to_c arg}.join(",")

      argnum = args.size - 1

      recvtype = infer_type(recv)

      if recvtype
        mobject = recvtype.instance_method(tree[2])

        address = getaddress(mobject)
        len = getlen(mobject)

        if address then
          if argnum == 0
            "((VALUE(*)(VALUE))0x#{address.to_s(16)})(#{to_c(recv)})"
          else
            "((VALUE(*)(VALUE,VALUE))0x#{address.to_s(16)})(#{to_c(recv)}, #{strargs})"
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
