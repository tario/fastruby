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
    attr_reader :yield_signature

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

      mname = call_tree[2]
      if mname == :infer
        return to_c(recv)
      elsif mname == :lvar_type
        lvar_name = args[1][1]
        lvar_type = eval(args[2][1].to_s)

        @infer_lvar_map[lvar_name] = lvar_type
        return ""
      elsif mname == :block_given?
        return "#{locals_accessor}block_function_address == 0 ? Qfalse : Qtrue"
      end

      other_call_tree = call_tree.dup
      other_call_tree[1] = s(:lvar, :arg)

      call_args_tree = call_tree[3]

      caller_code = nil

      str_lvar_initialization = @locals_struct + " *plocals;
                                plocals = (void*)param;"

      recvtype = infer_type(recv_tree || s(:self))

      address = nil
      mobject = nil
      len = nil

      convention = :ruby

      if recvtype

        inference_complete = true
        signature = [recvtype]

        call_args_tree[1..-1].each do |arg|
          argtype = infer_type(arg)
          if argtype
            signature << argtype
          else
            inference_complete = false
          end
        end

        convention = nil

        if recvtype.respond_to? :method_tree and inference_complete

          if recvtype.method_tree[call_tree[2]]
            mobject = recvtype.build(signature, call_tree[2])
            convention = :fastruby
          else
            mobject = recvtype.instance_method(call_tree[2])
            convention = :cruby
          end
        else
          mobject = recvtype.instance_method(call_tree[2])
          convention = :cruby
        end

        address = getaddress(mobject)
        len = getlen(mobject)

        unless address
          convention = :ruby
        end

      end

      anonymous_impl = tree[3]

      str_lvar_initialization = @locals_struct + " *plocals;
                                  plocals = (void*)param;"

      str_arg_initialization = ""



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


      if convention == :ruby or convention == :cruby

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
      elsif convention == :fastruby

        str_arg_initialization = ""

        if not args_tree
          str_arg_initialization = ""
        elsif args_tree.first == :lasgn
          str_arg_initialization = "plocals->#{args_tree[1]} = argv[0];"
        elsif args_tree.first == :masgn
          arguments = args_tree[1][1..-1].map(&:last)

          (0..arguments.size-1).each do |i|
            str_arg_initialization << "plocals->#{arguments[i]} = #{i} < argc ? argv[#{i}] : Qnil;\n"
          end
        end

        block_code = proc { |name| "
          static VALUE #{name}(int argc, VALUE* argv, VALUE param) {
            // block for call to #{call_tree[2]}

            #{str_lvar_initialization};
            #{str_arg_initialization}
            #{str_impl}
          }
        "
        }


        str_recv = "plocals->self"

        if recv_tree
           on_block do
             str_recv = to_c recv_tree
           end
        end

        if call_args_tree.size > 1
          value_cast = ( ["VALUE"]*(call_tree[3].size) ).join(",")
          value_cast = value_cast + ", VALUE" if convention == :fastruby

          str_called_code_args = nil
          on_block do
            str_called_code_args = call_tree[3][1..-1].map{|subtree| to_c subtree}.join(",")
          end

            caller_code = proc { |name| "
              static VALUE #{name}(VALUE param) {
                #{@block_struct} block;

                block.block_function_address = (void*)#{anonymous_function(block_code)};
                block.block_function_param = (void*)param;

                // call to #{call_tree[2]}

                #{str_lvar_initialization}

                return ((VALUE(*)(#{value_cast}))0x#{address.to_s(16)})(#{str_recv}, (VALUE)&block, #{str_called_code_args});
              }
            "
            }

        else
            caller_code = proc { |name| "
              static VALUE #{name}(VALUE param) {
                #{@block_struct} block;

                block.block_function_address = (void*)#{anonymous_function(block_code)};
                block.block_function_param = (void*)param;

                // call to #{call_tree[2]}
                #{str_lvar_initialization}

                return ((VALUE(*)(VALUE,VALUE))0x#{address.to_s(16)})(#{str_recv}, (VALUE)&block);
              }
            "
            }
        end

        "#{anonymous_function(caller_code)}((VALUE)&locals)"
      end
    end

    def to_c_yield(tree)

      block_code = proc { |name| "
        static VALUE #{name}(VALUE locals_param, VALUE* block_args) {

          #{@locals_struct} *plocals;
          plocals = (VALUE)locals_param;

          if (plocals->block_function_address == 0) {
            rb_raise(rb_eLocalJumpError, \"no block given\");
          } else {
            return ((VALUE(*)(int,VALUE*,VALUE))plocals->block_function_address)(#{tree.size-1}, block_args, plocals->block_function_param);
          }
        }
      "
      }

      @yield_signature = tree[1..-1].map{|subtree| infer_type subtree}

      if tree.size > 1
        anonymous_function(block_code)+"((VALUE)#{locals_pointer}, (VALUE[]){#{tree[1..-1].map{|subtree| to_c subtree}.join(",")}})"
      else
        anonymous_function(block_code)+"((VALUE)#{locals_pointer}, (VALUE[]){})"
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
        #{args_tree[1..-1].map{|arg| "VALUE #{arg};\n"}.join};
        void* block_function_address;
        VALUE block_function_param;
        }"

      @block_struct = "struct {
        void* block_function_address;
        void* block_function_param;
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

      "VALUE #{@alt_method_name || method_name}( VALUE block, #{args_tree[1..-1].map{|arg| "VALUE #{arg}" }.join(",") }  ) {
        #{@locals_struct} locals;
        #{@block_struct} *pblock;

        #{args_tree[1..-1].map { |arg|
          "locals.#{arg} = #{arg};\n"
        }.join("") }

        locals.self = self;

        pblock = (void*)block;
        if (pblock) {
          locals.block_function_address = pblock->block_function_address;
          locals.block_function_param = (VALUE)pblock->block_function_param;
        } else {
          locals.block_function_address = 0;
          locals.block_function_param = Qnil;
        }

        #{str_impl}
      }"
    end

    def locals_accessor
      @on_block ? "plocals->" : "locals."
    end

    def locals_pointer
      @on_block ? "plocals" : "&locals"
    end

    def to_c_gvar(tree)
      "rb_gvar_get((struct global_entry*)0x#{global_entry(tree[1]).to_s(16)})"
    end

    def to_c_gasgn(tree)
      "rb_gvar_set((struct global_entry*)0x#{global_entry(tree[1]).to_s(16)}, #{to_c tree[2]})"
    end

    def to_c_ivar(tree)
      "rb_ivar_get(#{locals_accessor}self,#{tree[1].to_i})"
    end

    def to_c_iasgn(tree)
      "rb_ivar_set(#{locals_accessor}self,#{tree[1].to_i},#{to_c tree[2]})"
    end

    def to_c_lasgn(tree)
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

          "#{locals_accessor}#{tree[1]} = #{anonymous_function(verify_type_function)}(#{to_c tree[2]})"
        else
          "#{locals_accessor}#{tree[1]} = #{to_c tree[2]}"
        end
      else
        "#{locals_accessor}#{tree[1]} = #{to_c tree[2]}"
      end
    end

    def to_c_lvar(tree)
      locals_accessor + tree[1].to_s
    end

    def to_c_self(tree)
      locals_accessor + "self"
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
      elsif mname == :block_given?
        return "#{locals_accessor}block_function_address == 0 ? Qfalse : Qtrue"
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

        convention = nil

        if recvtype.respond_to? :method_tree and inference_complete

          if recvtype.method_tree[tree[2]]
            mobject = recvtype.build(signature, tree[2])
            convention = :fastruby
          else
            mobject = recvtype.instance_method(tree[2])
            convention = :cruby
          end
        else
          mobject = recvtype.instance_method(tree[2])
          convention = :cruby
        end

        address = getaddress(mobject)
        len = getlen(mobject)

        extraargs = ""
        extraargs = ", Qfalse" if convention == :fastruby

        if address then
          if argnum == 0
            value_cast = "VALUE"
            value_cast = value_cast + ", VALUE" if convention == :fastruby

            if convention == :fastruby
              "((VALUE(*)(#{value_cast}))0x#{address.to_s(16)})(#{to_c recv}, Qfalse)"
            else
              wrapper_func = proc { |name| "
                static VALUE #{name}(VALUE recv) {
                  // call to #{recvtype}##{mname}
                  if (rb_block_given_p()) {
                    // no passing block, recall
                    return rb_funcall(recv, #{tree[2].to_i}, 0);
                  } else {
                    return ((VALUE(*)(#{value_cast}))0x#{address.to_s(16)})(recv);
                  }
                }
              " }

              anonymous_function(wrapper_func) + "(#{to_c(recv)})"

            end
          else
            value_cast = ( ["VALUE"]*(args.size) ).join(",")
            value_cast = value_cast + ", VALUE" if convention == :fastruby

            wrapper_func = nil
            if convention == :fastruby
              "((VALUE(*)(#{value_cast}))0x#{address.to_s(16)})(#{to_c recv}, Qfalse, #{strargs})"
            else
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

      builder.c "VALUE global_entry(VALUE global_id) {
        ID id = SYM2ID(global_id);
        struct global_entry* entry;

        entry = rb_global_entry(id);
        return INT2FIX(entry);
      }
      "
    end
  end
end
