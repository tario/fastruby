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
require "fastruby/method_extension"

module FastRuby
  class Context

    class UnwindFastrubyFrame < Exception
      def initialize(ex,target_frame,return_value)
        @ex = ex
        @target_frame = target_frame
        @return_value = return_value
      end
    end

    attr_accessor :infer_lvar_map
    attr_accessor :alt_method_name
    attr_accessor :locals
    attr_accessor :options
    attr_accessor :infer_self
    attr_reader :extra_code
    attr_reader :yield_signature

    def initialize(common_func = true)
      @infer_lvar_map = Hash.new
      @extra_code = ""
      @options = {}
      @frame_struct = "struct {
        void* parent_frame;
        void* target_frame;
        void* plocals;
        jmp_buf jmp;
        VALUE return_value;
        VALUE exception;
        int rescue;
        VALUE last_error;
      }"

      @block_struct = "struct {
        void* block_function_address;
        void* block_function_param;
      }"

      extra_code << '#include "node.h"
      '

      if common_func
        extra_code << "static VALUE _rb_gvar_set(void* ge,VALUE value) {
          rb_gvar_set((struct global_entry*)ge,value);
          return value;
        }
        "

        extra_code << "static VALUE _rb_ivar_set(VALUE recv,ID idvar, VALUE value) {
          rb_ivar_set(recv,idvar,value);
          return value;
        }
        "

        extra_code << "static VALUE _lvar_assing(VALUE* destination,VALUE value) {
          *destination = value;
          return value;
        }
        "
      end
    end

    def on_block
      yield
    end

    def to_c(tree)
      return "Qnil" unless tree
      send("to_c_" + tree[0].to_s, tree);
    end

    def anonymous_function

      name = "anonymous" + rand(10000000).to_s
      extra_code << yield(name)

      name
    end

    def to_c_dot2(tree)
      "rb_range_new(#{to_c tree[1]}, #{to_c tree[2]},0)"
    end

    def to_c_attrasgn(tree)
      to_c_call(tree)
    end

    def to_c_iter(tree)

      call_tree = tree[1]
      args_tree = tree[2]
      recv_tree = call_tree[1]

      directive_code = directive(call_tree)
      if directive_code
        return directive_code
      end

      other_call_tree = call_tree.dup
      other_call_tree[1] = s(:lvar, :arg)

      call_args_tree = call_tree[3]

      caller_code = nil

      recvtype = infer_type(recv_tree || s(:self))

      address = nil
      mobject = nil
      len = nil

      convention = :ruby

      extra_inference = {}

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

        if recvtype.respond_to? :fastruby_method and inference_complete

          method_tree = nil
          begin
            method_tree = recvtype.instance_method(call_tree[2]).fastruby.tree
          rescue NoMethodError
          end

          if method_tree
            mobject = recvtype.build(signature, call_tree[2])
            yield_signature = mobject.yield_signature

            if not args_tree
            elsif args_tree.first == :lasgn
              if yield_signature[0]
              extra_inference[args_tree.last] = yield_signature[0]
              end
            elsif args_tree.first == :masgn
              yield_args = args_tree[1][1..-1].map(&:last)
              (0...yield_signature.size-1).each do |i|
                extra_inference[yield_args[i]] = yield_signature[i]
              end
            end

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

      str_lvar_initialization = "#{@frame_struct} *pframe;
                                 #{@locals_struct} *plocals;
                                pframe = (void*)param;
                                plocals = (void*)pframe->plocals;
                                "

      str_arg_initialization = ""

      str_impl = ""

      with_extra_inference(extra_inference) do

        on_block do
          # if impl_tree is a block, implement the last node with a return
          if anonymous_impl
            if anonymous_impl[0] == :block
              str_impl = anonymous_impl[1..-2].map{ |subtree|
                to_c(subtree)
              }.join(";")

              if anonymous_impl[-1][0] != :return
                str_impl = str_impl + ";last_expression = (#{to_c(anonymous_impl[-1])});"
              else
                str_impl = str_impl + ";#{to_c(anonymous_impl[-1])};"
              end
            else
              if anonymous_impl[0] != :return
                str_impl = str_impl + ";last_expression = (#{to_c(anonymous_impl)});"
              else
                str_impl = str_impl + ";#{to_c(anonymous_impl)};"
              end
            end
          else
            str_impl = "last_expression = Qnil;"
          end
        end
      end

      if convention == :ruby or convention == :cruby

        if call_args_tree.size > 1

          str_called_code_args = call_args_tree[1..-1].map{ |subtree| to_c subtree }.join(",")
          str_recv = to_c recv_tree

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
          str_recv = to_c recv_tree
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
          static VALUE #{name}(VALUE arg, VALUE _plocals) {
            // block for call to #{call_tree[2]}
            VALUE last_expression = Qnil;

            #{@frame_struct} frame;
            #{@frame_struct} *pframe = (void*)&frame;
            #{@locals_struct} *plocals = (void*)_plocals;

            frame.plocals = plocals;
            frame.parent_frame = 0;
            frame.return_value = Qnil;
            frame.target_frame = &frame;
            frame.exception = Qnil;
            frame.rescue = 0;

            if (setjmp(frame.jmp) != 0) {
              if (pframe->target_frame != pframe) {
                if (pframe->target_frame == (void*)-3) {
                   return pframe->return_value;
                }

                VALUE ex = rb_funcall(
                        (VALUE)#{UnwindFastrubyFrame.internal_value},
                        #{:new.to_i},
                        3,
                        pframe->exception,
                        LONG2FIX(pframe->target_frame),
                        pframe->return_value
                        );

                rb_funcall(plocals->self, #{:raise.to_i}, 1, ex);
              }
              return frame.return_value;
            }


            #{str_arg_initialization}
            #{str_impl}

            return last_expression;
          }
        "
        }

        protected_block("rb_iterate(#{anonymous_function(&caller_code)}, (VALUE)pframe, #{anonymous_function(&block_code)}, (VALUE)plocals)", true)

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
          static VALUE #{name}(int argc, VALUE* argv, VALUE _locals, VALUE _parent_frame) {
            // block for call to #{call_tree[2]}
            VALUE last_expression = Qnil;
            #{@frame_struct} frame;
            #{@frame_struct} *pframe = (void*)&frame;
            #{@frame_struct} *parent_frame = (void*)_parent_frame;
            #{@locals_struct} *plocals;

            frame.plocals = (void*)_locals;
            frame.parent_frame = parent_frame;
            frame.return_value = Qnil;
            frame.target_frame = &frame;
            frame.exception = Qnil;
            frame.rescue = 0;

            plocals = frame.plocals;

            if (setjmp(frame.jmp) != 0) {
                if (pframe->target_frame != pframe) {
                  if (pframe->target_frame == (void*)-3) {
                     return pframe->return_value;
                  }
                  // raise exception
                  ((typeof(pframe))_parent_frame)->exception = pframe->exception;
                  ((typeof(pframe))_parent_frame)->target_frame = pframe->target_frame;
                  ((typeof(pframe))_parent_frame)->return_value = pframe->return_value;
                  longjmp(((typeof(pframe))_parent_frame)->jmp,1);
                }

            }

            #{str_arg_initialization}
            #{str_impl}

            return last_expression;
          }
        "
        }


        str_recv = "plocals->self"

        if recv_tree
           str_recv = to_c recv_tree
        end

        if call_args_tree.size > 1
          value_cast = ( ["VALUE"]*(call_tree[3].size) ).join(",")
          value_cast = value_cast + ", VALUE, VALUE" if convention == :fastruby

          str_called_code_args = call_tree[3][1..-1].map{|subtree| to_c subtree}.join(",")

            caller_code = proc { |name| "
              static VALUE #{name}(VALUE param, VALUE pframe) {
                #{@block_struct} block;
                #{@locals_struct} *plocals = (void*)param;

                block.block_function_address = (void*)#{anonymous_function(&block_code)};
                block.block_function_param = (void*)param;

                // call to #{call_tree[2]}

                return ((VALUE(*)(#{value_cast}))0x#{address.to_s(16)})(#{str_recv}, (VALUE)&block, (VALUE)pframe, #{str_called_code_args});
              }
            "
            }

        else
            caller_code = proc { |name| "
              static VALUE #{name}(VALUE param, VALUE pframe) {
                #{@block_struct} block;
                #{@locals_struct} *plocals = (void*)param;

                block.block_function_address = (void*)#{anonymous_function(&block_code)};
                block.block_function_param = (void*)param;

                // call to #{call_tree[2]}

                return ((VALUE(*)(VALUE,VALUE,VALUE))0x#{address.to_s(16)})(#{str_recv}, (VALUE)&block, (VALUE)pframe);
              }
            "
            }
        end

        "#{anonymous_function(&caller_code)}((VALUE)plocals, (VALUE)pframe)"
      end
    end

    def to_c_yield(tree)

      block_code = proc { |name| "
        static VALUE #{name}(VALUE frame_param, VALUE* block_args) {

          #{@locals_struct} *plocals;
          #{@frame_struct} *pframe;
          pframe = (void*)frame_param;
          plocals = (void*)pframe->plocals;

          if (plocals->block_function_address == 0) {
            rb_raise(rb_eLocalJumpError, \"no block given\");
          } else {
            return ((VALUE(*)(int,VALUE*,VALUE,VALUE))plocals->block_function_address)(#{tree.size-1}, block_args, plocals->block_function_param, (VALUE)pframe);
          }
        }
      "
      }

      new_yield_signature = tree[1..-1].map{|subtree| infer_type subtree}
      # merge the new_yield_signature with the new
      if @yield_signature
        if new_yield_signature.size == @yield_signature.size
          (0..new_yield_signature.size-1).each do |i|
            if @yield_signature[i] != new_yield_signature[i]
              @yield_signature[i] = nil
            end
          end
        else
          @yield_signature = new_yield_signature.map{|x| nil}
        end
      else
        @yield_signature = new_yield_signature
      end

      ret = if tree.size > 1
          anonymous_function(&block_code)+"((VALUE)pframe, (VALUE[]){#{tree[1..-1].map{|subtree| to_c subtree}.join(",")}})"
        else
          anonymous_function(&block_code)+"((VALUE)pframe, (VALUE[]){})"
        end

      protected_block(ret, true)
    end

    def to_c_block(tree)

      str = ""
      str = tree[1..-2].map{ |subtree|
        to_c(subtree)
      }.join(";")

      if tree[-1]

        if tree[-1][0] != :return
          str = str + ";last_expression = #{to_c(tree[-1])};"
        else
          str = str + ";#{to_c(tree[-1])};"
        end
      end

      str << "return last_expression;"

      inline_block str
    end

    def to_c_return(tree)
      "pframe->target_frame = ((typeof(pframe))plocals->pframe); plocals->return_value = #{to_c(tree[1])}; longjmp(pframe->jmp, 1); return Qnil;\n"
    end

    def to_c_break(tree)
      if @on_block
        inline_block(
         "
         pframe->target_frame = (void*)-2;
         pframe->return_value = #{tree[1] ? to_c(tree[1]) : "Qnil"};
         pframe->exception = Qnil;
         longjmp(pframe->jmp,1);"
         )
      else
        inline_block("
            pframe->target_frame = (void*)-1;
            pframe->exception = (VALUE)#{LocalJumpError.exception.internal_value};
            longjmp(pframe->jmp,1);
            return Qnil;
            ")

      end
    end

    def to_c_next(tree)
      if @on_block
       "Qnil; pframe->target_frame = (void*)-3; pframe->return_value = #{tree[1] ? to_c(tree[1]) : "Qnil"}; longjmp(pframe->jmp,1)"
      else
        inline_block("
            pframe->target_frame = (void*)-1;
            pframe->exception = (VALUE)#{LocalJumpError.exception.internal_value};
            longjmp(pframe->jmp,1);
            return Qnil;
            ")

      end
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
      (0..(tree.size-3)/2).each do |i|
        strkey = to_c tree[1 + i * 2]
        strvalue = to_c tree[2 + i * 2]
        hash_aset_code << "rb_hash_aset(hash, #{strkey}, #{strvalue});"
      end

      anonymous_function{ |name| "
        static VALUE #{name}(VALUE value_params) {
          #{@frame_struct} *pframe;
          #{@locals_struct} *plocals;
          pframe = (void*)value_params;
          plocals = (void*)pframe->plocals;

          VALUE hash = rb_hash_new();
          #{hash_aset_code}
          return hash;
        }
      " } + "((VALUE)pframe)"
    end

    def to_c_array(tree)
      if tree.size > 1
        strargs = tree[1..-1].map{|subtree| to_c subtree}.join(",")
        "rb_ary_new3(#{tree.size-1}, #{strargs})"
      else
        "rb_ary_new3(0)"
      end
    end

    def to_c_scope(tree)
      if tree[1]
        to_c(tree[1])
      else
        "Qnil"
      end
    end

    def to_c_cdecl(tree)
      if tree[1].instance_of? Symbol
        inline_block "
          // set constant #{tree[1].to_s}
          VALUE val = #{to_c tree[2]};
          rb_const_set(rb_cObject, #{tree[1].to_i}, val);
          return val;
          "
      elsif tree[1].instance_of? Sexp

        if tree[1].node_type == :colon2
          inline_block "
            // set constant #{tree[1].to_s}
            VALUE val = #{to_c tree[2]};
            VALUE klass = #{to_c tree[1][1]};
            rb_const_set(klass, #{tree[1][2].to_i}, val);
            return val;
            "
        elsif tree[1].node_type == :colon3
          inline_block "
            // set constant #{tree[1].to_s}
            VALUE val = #{to_c tree[2]};
            rb_const_set(rb_cObject, #{tree[1][1].to_i}, val);
            return val;
            "
        end
      end
    end

    def to_c_case(tree)
      "Qnil"
    end

    def to_c_const(tree)
      "rb_const_get(CLASS_OF(plocals->self), #{tree[1].to_i})"
    end

    def to_c_defn(tree)
      "rb_funcall(plocals->self,#{:fastruby.to_i},1,(VALUE)#{tree.internal_value})"
    end

    def to_c_defs(tree)
      args_tree = tree[3];

      tmp = FastRuby.build_defs(tree)

      extra_code << tmp[0]

      inline_block "
        rb_define_singleton_method(#{to_c tree[1]}, \"#{tree[2].to_s}\", (void*)#{tmp[1]}, #{args_tree.size-1});
        return Qnil;
        "
    end

    def to_c_defined(tree)
      nt = tree[1].node_type

      if nt == :self
      'rb_str_new2("self")'
      elsif nt == :true
      'rb_str_new2("true")'
      elsif nt == :false
      'rb_str_new2("false")'
      elsif nt == :nil
      'rb_str_new2("nil")'
      elsif nt == :lvar
      'rb_str_new2("local-variable")'
      elsif nt == :gvar
      "rb_gvar_defined((struct global_entry*)0x#{global_entry(tree[1][1]).to_s(16)}) ? #{"global-variable".internal_value} : Qnil"
      elsif nt == :const
      "rb_const_defined(rb_cObject, #{tree[1][1].to_i}) ? #{"constant".internal_value} : Qnil"
      elsif nt == :call
      "rb_method_node(CLASS_OF(#{to_c tree[1][1]}), #{tree[1][2].to_i}) ? #{"method".internal_value} : Qnil"
      elsif nt == :yield
        "rb_block_given_p() ? #{"yield".internal_value} : Qnil"
      elsif nt == :ivar
      "rb_ivar_defined(plocals->self,#{tree[1][1].to_i}) ? #{"instance-variable".internal_value} : Qnil"
      elsif nt == :attrset or
            nt == :op_asgn1 or
            nt == :op_asgn2 or
            nt == :op_asgn_or or
            nt == :op_asgn_and or
            nt == :op_asgn_masgn or
            nt == :masgn or
            nt == :lasgn or
            nt == :dasgn or
            nt == :dasgn_curr or
            nt == :gasgn or
            nt == :iasgn or
            nt == :cdecl or
            nt == :cvdecl or
            nt == :cvasgn
        "assignment".internal_value
      else
        "expression".internal_value
      end
    end

    def initialize_method_structs(args_tree)
      @locals_struct = "struct {
        void* block_function_address;
        VALUE block_function_param;
        jmp_buf jmp;
        VALUE return_value;
        void* pframe;
        #{@locals.map{|l| "VALUE #{l};\n"}.join}
        #{args_tree[1..-1].map{|arg| "VALUE #{arg};\n"}.join};
        }"
    end

    def to_c_method_defs(tree)

      method_name = tree[2]
      args_tree = tree[3]

      impl_tree = tree[4][1]

      initialize_method_structs(args_tree)

      strargs = if args_tree.size > 1
        "VALUE self, void* block_address, VALUE block_param, void* _parent_frame, #{args_tree[1..-1].map{|arg| "VALUE #{arg}" }.join(",") }"
      else
        "VALUE self, void* block_address, VALUE block_param, void* _parent_frame"
      end

      extra_code << "static VALUE #{@alt_method_name + "_real"}(#{strargs}) {
        #{func_frame}

        #{args_tree[1..-1].map { |arg|
          "locals.#{arg} = #{arg};\n"
        }.join("") }

        locals.block_function_address = block_address;
        locals.block_function_param = block_param;

        return #{to_c impl_tree};
      }"

      strargs2 = if args_tree.size > 1
        "VALUE self, #{args_tree[1..-1].map{|arg| "VALUE #{arg}" }.join(",") }"
      else
        "VALUE self"
      end

      value_cast = ( ["VALUE"]*(args_tree.size+1) ).join(",")
      strmethodargs = ""

      if args_tree.size > 1
        strmethodargs = "self,block_address,block_param,&frame,#{args_tree[1..-1].map(&:to_s).join(",") }"
      else
        strmethodargs = "self,block_address,block_param,&frame"
      end

      "
      VALUE #{@alt_method_name}(#{strargs2}) {
          #{@frame_struct} frame;
          int argc = #{args_tree.size};
          void* block_address = 0;
          VALUE block_param = Qnil;


          frame.plocals = 0;
          frame.parent_frame = 0;
          frame.return_value = Qnil;
          frame.target_frame = &frame;
          frame.exception = Qnil;
          frame.rescue = 0;

          if (rb_block_given_p()) {
            block_address = #{
              anonymous_function{|name|
              "static VALUE #{name}(int argc, VALUE* argv, VALUE param) {
                return rb_yield_splat(rb_ary_new4(argc,argv));
              }"
              }
            };

            block_param = 0;
          }

          int aux = setjmp(frame.jmp);
          if (aux != 0) {
            rb_funcall(self, #{:raise.to_i}, 1, frame.exception);
          }


          return #{@alt_method_name + "_real"}(#{strmethodargs});
      }
      "
    end

    def to_c_method(tree)
      method_name = tree[1]
      args_tree = tree[2]

      impl_tree = tree[3][1]

      initialize_method_structs(args_tree)

      strargs = if args_tree.size > 1
        "VALUE block, VALUE _parent_frame, #{args_tree[1..-1].map{|arg| "VALUE #{arg}" }.join(",") }"
      else
        "VALUE block, VALUE _parent_frame"
      end

      "VALUE #{@alt_method_name || method_name}(#{strargs}) {

        #{func_frame}

        #{args_tree[1..-1].map { |arg|
          "locals.#{arg} = #{arg};\n"
        }.join("") }

        pblock = (void*)block;
        if (pblock) {
          locals.block_function_address = pblock->block_function_address;
          locals.block_function_param = (VALUE)pblock->block_function_param;
        } else {
          locals.block_function_address = 0;
          locals.block_function_param = Qnil;
        }

        return #{to_c impl_tree};
      }"
    end

    def locals_accessor
      "plocals->"
    end

    def to_c_gvar(tree)
      "rb_gvar_get((struct global_entry*)0x#{global_entry(tree[1]).to_s(16)})"
    end

    def to_c_gasgn(tree)
      "_rb_gvar_set((void*)0x#{global_entry(tree[1]).to_s(16)}, #{to_c tree[2]})"
    end

    def to_c_ivar(tree)
      "rb_ivar_get(#{locals_accessor}self,#{tree[1].to_i})"
    end

    def to_c_iasgn(tree)
      "_rb_ivar_set(#{locals_accessor}self,#{tree[1].to_i},#{to_c tree[2]})"
    end

    def to_c_colon3(tree)
      "rb_const_get_from(rb_cObject, #{tree[1].to_i})"
    end
    def to_c_colon2(tree)
      inline_block "
        VALUE klass = #{to_c tree[1]};

      if (rb_is_const_id(#{tree[2].to_i})) {
        switch (TYPE(klass)) {
          case T_CLASS:
          case T_MODULE:
            return rb_const_get_from(klass, #{tree[2].to_i});
            break;
          default:
            rb_raise(rb_eTypeError, \"%s is not a class/module\",
               RSTRING(rb_obj_as_string(klass))->ptr);
            break;
        }
      }
      else {
        return rb_funcall(klass, #{tree[2].to_i}, 0, 0);
      }

        return Qnil;
      "
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


          "_lvar_assing(&#{locals_accessor}#{tree[1]}, #{anonymous_function(&verify_type_function)}(#{to_c tree[2]}))"
        else
          "_lvar_assing(&#{locals_accessor}#{tree[1]},#{to_c tree[2]})"
        end
      else
        "_lvar_assing(&#{locals_accessor}#{tree[1]},#{to_c tree[2]})"
      end
    end

    def to_c_lvar(tree)
      locals_accessor + tree[1].to_s
    end

    def to_c_self(tree)
      locals_accessor + "self"
    end

    def to_c_false(tree)
      "Qfalse"
    end

    def to_c_true(tree)
      "Qtrue"
    end

    def to_c_and(tree)
      "(RTEST(#{to_c tree[1]}) && RTEST(#{to_c tree[2]})) ? Qtrue : Qfalse"
    end

    def to_c_or(tree)
      "(RTEST(#{to_c tree[1]}) || RTEST(#{to_c tree[2]})) ? Qtrue : Qfalse"
    end

    def to_c_not(tree)
      "RTEST(#{to_c tree[1]}) ? Qfalse : Qtrue"
    end

    def to_c_if(tree)
      condition_tree = tree[1]
      impl_tree = tree[2]
      else_tree = tree[3]

      inline_block "
          if (RTEST(#{to_c condition_tree})) {
            last_expression = #{to_c impl_tree};
          }#{else_tree ?
            " else {
            last_expression = #{to_c else_tree};
            }
            " : ""
          }

          return last_expression;
      "
    end

    def to_c_rescue(tree)
      if tree[1][0] == :resbody
        else_tree = tree[2]

        if else_tree
          to_c else_tree
        else
          "Qnil"
        end
      else
        resbody_tree = tree[2]
        else_tree = tree[3]

        frame(to_c(tree[1])+";","
          if (CLASS_OF(frame.exception) == #{to_c(resbody_tree[1][1])})
          {
            // trap exception
            ;original_frame->target_frame = &frame;
             #{to_c(resbody_tree[2])};
          }
          ", else_tree ? to_c(else_tree) : nil, 1)
      end
    end

    def to_c_ensure(tree)
      if tree.size == 2
        to_c tree[1]
      else
        ensured_code = to_c tree[2]
        inline_block "
          #{frame(to_c(tree[1]),ensured_code,ensured_code,1)};
        "
      end
    end

    def to_c_call(tree)
      directive_code = directive(tree)
      if directive_code
        return directive_code
      end

      if tree[2] == :require
        tree[2] = :fastruby_require
      elsif tree[2] == :raise
        # raise code
        args = tree[3]

        return inline_block("
            pframe->target_frame = (void*)-1;
            pframe->exception = rb_funcall(#{to_c args[1]}, #{:exception.to_i},0);
            longjmp(pframe->jmp, 1);
            return Qnil;
            ")
      end

      recv = tree[1]
      mname = tree[2]
      args = tree[3]

      mname = :require_fastruby if mname == :require

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

        if recvtype.respond_to? :fastruby_method and inference_complete

          method_tree = nil
          begin
            method_tree = recvtype.instance_method(tree[2]).fastruby.tree
          rescue NoMethodError
          end

          if method_tree
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

        address = nil
        len = 0
        if mobject
          address = getaddress(mobject)
          len = getlen(mobject)
        end

        extraargs = ""
        extraargs = ", Qfalse" if convention == :fastruby

        if address then
          if argnum == 0
            value_cast = "VALUE"
            value_cast = value_cast + ", VALUE,VALUE" if convention == :fastruby

            if convention == :fastruby
              "((VALUE(*)(#{value_cast}))0x#{address.to_s(16)})(#{to_c recv}, Qfalse, (VALUE)pframe)"
            else

              str_incall_args = nil
              if len == -1
                str_incall_args = "0, (VALUE[]){}, recv"
                value_cast = "int,VALUE*,VALUE"
              elsif len == -2
                str_incall_args = "recv, rb_ary_new4(#{})"
                value_cast = "VALUE,VALUE"
              else
                str_incall_args = "recv"
              end

              protected_block(

                anonymous_function{ |name| "
                  static VALUE #{name}(VALUE recv) {
                    // call to #{recvtype}##{mname}
                    if (rb_block_given_p()) {
                      // no passing block, recall
                      return rb_funcall(recv, #{tree[2].to_i}, 0);
                    } else {
                      return ((VALUE(*)(#{value_cast}))0x#{address.to_s(16)})(#{str_incall_args});
                    }
                  }
                " } + "(#{to_c(recv)})"
              )
            end
          else
            value_cast = ( ["VALUE"]*(args.size) ).join(",")
            value_cast = value_cast + ", VALUE, VALUE" if convention == :fastruby

            wrapper_func = nil
            if convention == :fastruby
              "((VALUE(*)(#{value_cast}))0x#{address.to_s(16)})(#{to_c recv}, Qfalse, (VALUE)pframe, #{strargs})"
            else

              str_incall_args = nil
              if len == -1
                str_incall_args = "#{argnum}, (VALUE[]){#{ (1..argnum).map{|x| "_arg"+x.to_s }.join(",")}}, recv"
                value_cast = "int,VALUE*,VALUE"
              elsif len == -2
                str_incall_args = "recv, rb_ary_new4(#{ (1..argnum).map{|x| "_arg"+x.to_s }.join(",")})"
                value_cast = "VALUE,VALUE"
              else
                str_incall_args = "recv, #{ (1..argnum).map{|x| "_arg"+x.to_s }.join(",")}"
              end

              protected_block(

                anonymous_function{ |name| "
                  static VALUE #{name}(VALUE recv, #{ (1..argnum).map{|x| "VALUE _arg"+x.to_s }.join(",")} ) {
                    // call to #{recvtype}##{mname}
                    if (rb_block_given_p()) {
                      // no passing block, recall
                      return rb_funcall(recv, #{tree[2].to_i}, #{argnum}, #{ (1..argnum).map{|x| "_arg"+x.to_s }.join(",")});
                    } else {
                      return ((VALUE(*)(#{value_cast}))0x#{address.to_s(16)})(#{str_incall_args});
                    }
                  }
                " } + "(#{to_c(recv)}, #{strargs})"
              )
            end
          end
        else

          if argnum == 0
            protected_block("rb_funcall(#{to_c recv}, #{tree[2].to_i}, 0)")
          else
            protected_block("rb_funcall(#{to_c recv}, #{tree[2].to_i}, #{argnum}, #{strargs} )")
          end
        end

      else
        if argnum == 0
          protected_block("rb_funcall(#{to_c recv}, #{tree[2].to_i}, 0)")
        else
          protected_block("rb_funcall(#{to_c recv}, #{tree[2].to_i}, #{argnum}, #{strargs} )")
        end
      end
    end

    def to_c_class(tree)
      inline_block("
        rb_funcall(plocals->self,#{:fastruby.to_i},1,(VALUE)#{tree.internal_value});
        return Qnil;
      ")

    end

    def to_c_module(tree)
      inline_block("
        rb_funcall(plocals->self,#{:fastruby.to_i},1,(VALUE)#{tree.internal_value});
        return Qnil;
      ")
    end

    def to_c_while(tree)
      inline_block("
          while (#{to_c tree[1]}) {
            #{to_c tree[2]};
          }
          return Qnil;
      ")
    end

    def infer_type(recv)
      if recv[0] == :call
        if recv[2] == :infer
          eval(recv[3].last.last.to_s)
        end
      elsif recv[0] == :lvar
        @infer_lvar_map[recv[1]]
      elsif recv[0] == :self
        @infer_self
      elsif recv[0] == :str or recv[0] == :lit
        recv[1].class
      else
        nil
      end
    end

    def on_block
      old_on_block = @on_block
      @on_block = true
      return yield
    ensure
      @on_block = old_on_block
    end

    def with_extra_inference(extra_inference)
      previous_infer_lvar_map = @infer_lvar_map
      begin
        @infer_lvar_map = @infer_lvar_map.merge(extra_inference)
        yield
      ensure
        @infer_lvar_map = previous_infer_lvar_map
      end
    end

    def directive(tree)
      recv = tree[1]
      mname = tree[2]
      args = tree[3]

      if mname == :infer
        return to_c(recv)
      elsif mname == :lvar_type
        lvar_name = args[1][1] || args[1][2]
        lvar_type = eval(args[2][1].to_s)

        @infer_lvar_map[lvar_name] = lvar_type
        return ""
      elsif mname == :block_given?
        return "#{locals_accessor}block_function_address == 0 ? Qfalse : Qtrue"
      elsif mname == :inline_c
        code = args[1][1]

        return anonymous_function{ |name| "
           static VALUE #{name}(VALUE param) {
            #{@frame_struct} *pframe = (void*)param;
            #{@locals_struct} *plocals = (void*)pframe->plocals;
            #{code};
            return Qnil;
          }
         "
        }+"((VALUE)pframe)"
      else
        nil
      end
    end

    def inline_block_reference(arg)
      code = nil

      if arg.instance_of? Sexp
        code = to_c(arg);
      else
        code = arg
      end

      anonymous_function{ |name| "
        static VALUE #{name}(VALUE param) {
          #{@frame_struct} *pframe = (void*)param;
          #{@locals_struct} *plocals = (void*)pframe->plocals;
          VALUE last_expression = Qnil;

          #{code};
          return last_expression;
          }
        "
      }
    end

    def inline_block(code)
      anonymous_function{ |name| "
        static VALUE #{name}(VALUE param) {
          #{@frame_struct} *pframe = (void*)param;
          #{@locals_struct} *plocals = (void*)pframe->plocals;
          VALUE last_expression = Qnil;

          #{code}
          }
        "
      } + "((VALUE)pframe)"
    end

    def inline_ruby(proced, parameter)
      "rb_funcall(#{proced.internal_value}, #{:call.to_i}, 1, #{parameter})"
    end

    def wrapped_break_block(inner_code)
      frame("return " + inner_code, "
            if (original_frame->target_frame == (void*)-2) {
              return pframe->return_value;
            }
            ")
    end

    def protected_block(inner_code, always_rescue = false)
      wrapper_code = "
         if (pframe->last_error != Qnil) {
              if (CLASS_OF(pframe->last_error)==(VALUE)#{UnwindFastrubyFrame.internal_value}) {
              #{@frame_struct} *pframe = (void*)param;

                pframe->target_frame = (void*)FIX2LONG(rb_ivar_get(pframe->last_error, #{:@target_frame.to_i}));
                pframe->exception = rb_ivar_get(pframe->last_error, #{:@ex.to_i});
                pframe->return_value = rb_ivar_get(pframe->last_error, #{:@return_value.to_i});

               if (pframe->target_frame == (void*)-2) {
                  return pframe->return_value;
               }

                longjmp(pframe->jmp, 1);
                return Qnil;

              } else {

                // raise emulation
                  #{@frame_struct} *pframe = (void*)param;
                  pframe->target_frame = (void*)-1;
                  pframe->exception = pframe->last_error;
                  longjmp(pframe->jmp, 1);
                  return Qnil;
              }

          }
      "
      rescue_code = "rb_rescue2(#{inline_block_reference "return #{inner_code};"},(VALUE)pframe,#{anonymous_function{|name| "
        static VALUE #{name}(VALUE param, VALUE error) {
            #{@frame_struct} *pframe = (void*)param;
            pframe->last_error = error;
          }
      "}}
      ,(VALUE)pframe, rb_eException,(VALUE)0)"

      if always_rescue
        inline_block "
          pframe->last_error = Qnil;
          VALUE result = #{rescue_code};

          #{wrapper_code}

          return result;
        "
      else
        inline_block "
          VALUE result;
          pframe->last_error = Qnil;

          if (pframe->rescue) {
            result = #{rescue_code};
          } else {
            return #{inner_code};
          }

          #{wrapper_code}

          return result;
        "
      end

    end


    def func_frame
      "
        #{@locals_struct} locals;
        #{@locals_struct} *plocals = (void*)&locals;
        #{@frame_struct} frame;
        #{@frame_struct} *pframe;

        frame.plocals = plocals;
        frame.parent_frame = (void*)_parent_frame;
        frame.return_value = Qnil;
        frame.target_frame = &frame;
        frame.exception = Qnil;
        frame.rescue = 0;

        locals.pframe = &frame;

        pframe = (void*)&frame;

        #{@block_struct} *pblock;
        VALUE last_expression = Qnil;

        int aux = setjmp(pframe->jmp);
        if (aux != 0) {

          if (pframe->target_frame == (void*)-2) {
            return pframe->return_value;
          }

          if (pframe->target_frame != pframe) {
            // raise exception
            ((typeof(pframe))_parent_frame)->exception = pframe->exception;
            ((typeof(pframe))_parent_frame)->target_frame = pframe->target_frame;
            ((typeof(pframe))_parent_frame)->return_value = pframe->return_value;
            longjmp(((typeof(pframe))_parent_frame)->jmp,1);
          }

          return plocals->return_value;
        }

        locals.self = self;
      "
    end


    def frame(code, jmp_code, not_jmp_code = "", rescued = nil)

      anonymous_function{ |name| "
        static VALUE #{name}(VALUE param) {
          VALUE last_expression;
          #{@frame_struct} frame, *pframe, *parent_frame;
          #{@locals_struct} *plocals;

          parent_frame = (void*)param;

          frame.parent_frame = (void*)param;
          frame.plocals = parent_frame->plocals;
          frame.target_frame = &frame;
          frame.rescue = #{rescued ? rescued : "parent_frame->rescue"};

          plocals = frame.plocals;
          pframe = &frame;

          int aux = setjmp(frame.jmp);
          if (aux != 0) {
            last_expression = pframe->return_value;

            // restore previous frame
            typeof(pframe) original_frame = pframe;
            pframe = parent_frame;

            #{jmp_code};

            if (original_frame->target_frame != original_frame) {
              pframe->exception = original_frame->exception;
              pframe->target_frame = original_frame->target_frame;
              pframe->return_value = original_frame->return_value;
              longjmp(pframe->jmp,1);
            }

            return last_expression;
          }

          #{code};

          // restore previous frame
          typeof(pframe) original_frame = pframe;
          pframe = parent_frame;
          #{not_jmp_code};

          return last_expression;

          }
        "
      } + "((VALUE)pframe)"
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
