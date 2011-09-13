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
require "set"
require "fastruby/method_extension"
require "fastruby/set_tree"
require "fastruby/exceptions"
require "rubygems"
require "sexp"

module FastRuby
  class Context
    attr_accessor :infer_lvar_map
    attr_accessor :alt_method_name
    attr_accessor :locals
    attr_accessor :options
    attr_accessor :infer_self
    attr_accessor :snippet_hash
    attr_reader :no_cache
    attr_reader :init_extra
    attr_reader :extra_code
    attr_reader :yield_signature

    def initialize(common_func = true)
      @infer_lvar_map = Hash.new
      @no_cache = false
      @extra_code = ""
      @options = {}
      @init_extra = Array.new
      @frame_struct = "struct {
        void* parent_frame;
        void* target_frame;
        void* plocals;
        jmp_buf jmp;
        VALUE return_value;
        VALUE exception;
        int rescue;
        VALUE last_error;
        void* stack_chunk;
      }"

      @block_struct = "struct {
        void* block_function_address;
        void* block_function_param;
      }"


      extra_code << '#include "node.h"

      struct STACKCHUNK;
      void* stack_chunk_alloc(struct STACKCHUNK* sc, int size);
      VALUE rb_stack_chunk_create(VALUE self);
      int stack_chunk_get_current_position(struct STACKCHUNK* sc);
      void stack_chunk_set_current_position(struct STACKCHUNK* sc, int position);

      '

      ruby_code = "
        $LOAD_PATH << #{FastRuby.fastruby_load_path.inspect}
        require #{FastRuby.fastruby_script_path.inspect}
      "

      init_extra << "
        rb_eval_string(#{ruby_code.inspect});
    	"



      @common_func = common_func
      if common_func
        extra_code << "static VALUE _rb_gvar_set(void* ge,VALUE value) {
          rb_gvar_set((struct global_entry*)ge,value);
          return value;
        }
        "

        extra_code << "static VALUE re_yield(int argc, VALUE* argv, VALUE param, VALUE _parent_frame) {
        return rb_yield_splat(rb_ary_new4(argc,argv));
        }"

        extra_code << "static VALUE _rb_ivar_set(VALUE recv,ID idvar, VALUE value) {
          rb_ivar_set(recv,idvar,value);
          return value;
        }
        "

        extra_code << "static VALUE __rb_cvar_set(VALUE recv,ID idvar, VALUE value, int warn) {
          rb_cvar_set(recv,idvar,value,warn);
          return value;
        }
        "

        extra_code << "static VALUE _lvar_assing(VALUE* destination,VALUE value) {
          *destination = value;
          return value;
        }

/*
       #{caller.join("\n")}
*/

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

      mname = call_tree[2]

      call_args_tree = call_tree[3]

      caller_code = nil

      recvtype = infer_type(recv_tree || s(:self))

      address = nil
      mobject = nil
      len = nil

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
          end
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
        rb_funcall_caller_code = nil

        if call_args_tree.size > 1

          str_called_code_args = call_args_tree[1..-1].map{ |subtree| to_c subtree }.join(",")
          str_recv = to_c recv_tree

          str_recv = "plocals->self" unless recv_tree

            rb_funcall_caller_code = proc { |name| "
              static VALUE #{name}(VALUE param) {
                // call to #{call_tree[2]}

                #{str_lvar_initialization}
                return rb_funcall(#{str_recv}, #{intern_num call_tree[2]}, #{call_args_tree.size-1}, #{str_called_code_args});
              }
            "
            }

        else
          str_recv = to_c recv_tree
          str_recv = "plocals->self" unless recv_tree

            rb_funcall_caller_code = proc { |name| "
              static VALUE #{name}(VALUE param) {
                // call to #{call_tree[2]}
                #{str_lvar_initialization}
                return rb_funcall(#{str_recv}, #{intern_num call_tree[2]}, 0);
              }
            "
            }
        end


        rb_funcall_block_code = proc { |name| "
          static VALUE #{name}(VALUE arg, VALUE _plocals) {
            // block for call to #{call_tree[2]}
            VALUE last_expression = Qnil;

            #{@frame_struct} frame;
            #{@frame_struct} *pframe = (void*)&frame;
            #{@locals_struct} *plocals = (void*)_plocals;

            frame.plocals = plocals;
            frame.stack_chunk = 0;
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
                        #{literal_value FastRuby::Context::UnwindFastrubyFrame},
                        #{intern_num :new},
                        3,
                        pframe->exception,
                        LONG2FIX(pframe->target_frame),
                        pframe->return_value
                        );

                rb_funcall(plocals->self, #{intern_num :raise}, 1, ex);
              }
              return frame.return_value;
            }


            #{str_arg_initialization}
            #{str_impl}

            return last_expression;
          }
        "
        }


        fastruby_str_arg_initialization = ""

        if not args_tree
          fastruby_str_arg_initialization = ""
        elsif args_tree.first == :lasgn
          fastruby_str_arg_initialization = "plocals->#{args_tree[1]} = argv[0];"
        elsif args_tree.first == :masgn
          arguments = args_tree[1][1..-1].map(&:last)

          (0..arguments.size-1).each do |i|
            fastruby_str_arg_initialization << "plocals->#{arguments[i]} = #{i} < argc ? argv[#{i}] : Qnil;\n"
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
            frame.stack_chunk = parent_frame->stack_chunk;
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

            #{fastruby_str_arg_initialization}
            #{str_impl}

            return last_expression;
          }
        "
        }

        str_recv = "plocals->self"

        if recv_tree
           str_recv = to_c recv_tree
        end

        caller_code = nil
        convention_global_name = add_global_name("int",0)

        if call_args_tree.size > 1
          value_cast = ( ["VALUE"]*(call_tree[3].size) ).join(",") + ", VALUE, VALUE"

          str_called_code_args = call_tree[3][1..-1].map{|subtree| to_c subtree}.join(",")

            caller_code = proc { |name| "
              static VALUE #{name}(VALUE param, VALUE pframe) {
                #{@block_struct} block;
                #{@locals_struct} *plocals = (void*)param;

                block.block_function_address = (void*)#{anonymous_function(&block_code)};
                block.block_function_param = (void*)param;

                // call to #{call_tree[2]}

                return ((VALUE(*)(#{value_cast}))#{encode_address(recvtype,signature,mname,call_tree,inference_complete,convention_global_name)})(#{str_recv}, (VALUE)&block, (VALUE)pframe, #{str_called_code_args});
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

                return ((VALUE(*)(VALUE,VALUE,VALUE))#{encode_address(recvtype,signature,mname,call_tree,inference_complete,convention_global_name)})(#{str_recv}, (VALUE)&block, (VALUE)pframe);
              }
            "
            }
        end

      inline_block "
        if (#{convention_global_name}) {
          return #{anonymous_function(&caller_code)}((VALUE)plocals, (VALUE)pframe);
        } else {
          return #{
            protected_block("rb_iterate(#{anonymous_function(&rb_funcall_caller_code)}, (VALUE)pframe, #{anonymous_function(&rb_funcall_block_code)}, (VALUE)plocals)", true)
          };
        }
      "
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

      protected_block(ret, false)
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

    def to_c_cvar(tree)
      "rb_cvar_get(CLASS_OF(plocals->self) != rb_cClass ? CLASS_OF(plocals->self) : plocals->self,#{intern_num tree[1]})"
    end

    def to_c_cvasgn(tree)
      "__rb_cvar_set(CLASS_OF(plocals->self) != rb_cClass ? CLASS_OF(plocals->self) : plocals->self,#{intern_num tree[1]},#{to_c tree[2]},Qfalse)"
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
            pframe->exception = #{literal_value LocalJumpError.exception};
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
            pframe->exception = #{literal_value LocalJumpError.exception};
            longjmp(pframe->jmp,1);
            return Qnil;
            ")

      end
    end

    def to_c_lit(tree)
      literal_value tree[1]
    end

    def to_c_nil(tree)
      "Qnil"
    end

    def to_c_str(tree)
      literal_value tree[1]
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
          rb_const_set(rb_cObject, #{intern_num tree[1]}, val);
          return val;
          "
      elsif tree[1].instance_of? FastRuby::FastRubySexp

        if tree[1].node_type == :colon2
          inline_block "
            // set constant #{tree[1].to_s}
            VALUE val = #{to_c tree[2]};
            VALUE klass = #{to_c tree[1][1]};
            rb_const_set(klass, #{intern_num tree[1][2]}, val);
            return val;
            "
        elsif tree[1].node_type == :colon3
          inline_block "
            // set constant #{tree[1].to_s}
            VALUE val = #{to_c tree[2]};
            rb_const_set(rb_cObject, #{intern_num tree[1][1]}, val);
            return val;
            "
        end
      end
    end

    def to_c_case(tree)

      tmpvarname = "tmp" + rand(1000000).to_s;

      code = tree[2..-2].map{|subtree|

              # this subtree is a when
            subtree[1][1..-1].map{|subsubtree|
              c_calltree = s(:call, nil, :inline_c, s(:arglist, s(:str, tmpvarname), s(:false)))
              calltree = s(:call, subsubtree, :===, s(:arglist, c_calltree))
              "
                if (RTEST(#{to_c_call(calltree, tmpvarname)})) {
                   return #{to_c(subtree[2])};
                }

              "
            }.join("\n")

          }.join("\n")

      inline_block "

        VALUE #{tmpvarname} = #{to_c tree[1]};

        #{code};

        return #{to_c tree[-1]};
      "
    end

    def to_c_const(tree)
      "rb_const_get(CLASS_OF(plocals->self), #{intern_num(tree[1])})"
    end

    def to_c_defn(tree)

      method_name = tree[1]
      args_tree = tree[2]

      global_klass_variable = add_global_name("VALUE", "Qnil");

      hash = Hash.new
      value_cast = ( ["VALUE"]*(args_tree.size+2) ).join(",")

      strmethodargs = ""
      strmethodargs_class = (["self"] + args_tree[1..-1]).map{|arg| "CLASS_OF(#{arg.to_s})"}.join(",")

      if args_tree.size > 1
        strmethodargs = "self,block,(VALUE)&frame,#{args_tree[1..-1].map(&:to_s).join(",") }"
      else
        strmethodargs = "self,block,(VALUE)&frame"
      end

      strmethod_signature = (["self"] + args_tree[1..-1]).map { |arg|
        "sprintf(method_name+strlen(method_name), \"%lu\", FIX2LONG(rb_obj_id(CLASS_OF(#{arg}))));\n"
      }.join

      anonymous_method_name = anonymous_function{ |name| "VALUE #{name}(#{(["self"]+args_tree[1..-1]).map{|arg| "VALUE #{arg}" }.join(",")}) {

          VALUE klass = #{global_klass_variable};
          char method_name[0x100];

          method_name[0] = '_';
          method_name[1] = 0;

          rb_dvar_push(#{intern_num :__stack_chunk}, Qnil);
          rb_newobj();

          sprintf(method_name+1, \"#{method_name}\");
          #{strmethod_signature}

          NODE* body;
          ID id;

          id = rb_intern(method_name);
          body = rb_method_node(klass,id);

          if (body == 0) {
            VALUE argv_class[] = {#{strmethodargs_class} };
            VALUE signature = rb_ary_new4(#{args_tree.size},argv_class);

            VALUE mobject = rb_funcall(#{global_klass_variable}, #{intern_num :build}, 2, signature,rb_str_new2(#{method_name.to_s.inspect}));

            struct METHOD {
              VALUE klass, rklass;
              VALUE recv;
              ID id, oid;
              int safe_level;
              NODE *body;
            };

            struct METHOD *data;
            Data_Get_Struct(mobject, struct METHOD, data);
            body = data->body;

            if (body == 0) {
              rb_raise(rb_eRuntimeError,\"method not found after build: '%s'\", method_name);
            }
          }

            if (nd_type(body) == NODE_CFUNC) {
              struct {
                void* parent_frame;
                void* target_frame;
                void* plocals;
                jmp_buf jmp;
                VALUE return_value;
                VALUE exception;
                int rescue;
                VALUE last_error;
                void* stack_chunk;
              } frame;

              frame.stack_chunk = 0;
              frame.target_frame = 0;
              frame.parent_frame = 0;
              frame.rescue = 0;
              frame.exception = Qnil;
              frame.return_value = Qnil;

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

              int aux = setjmp(frame.jmp);
              if (aux != 0) {
                if (frame.target_frame == (void*)-1) {
                  rb_funcall(self, #{intern_num :raise}, 1, frame.exception);
                }

                if (frame.target_frame != &frame) {
                    VALUE ex = rb_funcall(
                            #{literal_value FastRuby::Context::UnwindFastrubyFrame},
                            #{intern_num :new},
                            3,
                            frame.exception,
                            LONG2FIX(frame.target_frame),
                            frame.return_value
                            );

                    rb_funcall(self, #{intern_num :raise}, 1, ex);
                }

                return Qnil;
              }

              if (argc == #{args_tree.size+1}) {
                return ((VALUE(*)(#{value_cast}))body->nd_cfnc)(#{strmethodargs});
              } else if (argc == -1) {
                VALUE argv[] = {#{(["block,(VALUE)&frame"]+args_tree[1..-1]).map(&:to_s).join(",")} };
                return ((VALUE(*)(int,VALUE*,VALUE))body->nd_cfnc)(#{args_tree.size},argv,self);
              } else if (argc == -2) {
                VALUE argv[] = {#{(["block,(VALUE)&frame"]+args_tree[1..-1]).map(&:to_s).join(",")} };
                return ((VALUE(*)(VALUE,VALUE))body->nd_cfnc)(self, rb_ary_new4(#{args_tree.size},argv));
              } else {
                rb_raise(rb_eArgError, \"wrong number of arguments (#{args_tree.size-1} for %d)\", argc);
              }
            }

          return Qnil;
        }"
      }

      alt_options = options.dup

      alt_options.delete(:self)
      alt_options.delete(:main)

      real_method_name = "_" + method_name.to_s + "_real__"
      ruby_wrapper_code = "lambda {|x|
      x.class_eval do
        def #{method_name}(*args)
          __stack_chunks = []
          if block_given?
            #{real_method_name}(*args) do |*x|
              yield(*x)
            end
          else
            #{real_method_name}(*args)
          end
        end
      end
    }"

      inline_block "
        #{global_klass_variable} = plocals->self;

        // set tree
        rb_funcall(#{literal_value FastRuby}, #{intern_num :set_tree}, 5,
                #{global_klass_variable},
                rb_str_new2(#{method_name.to_s.inspect}),
                #{literal_value tree},
                #{literal_value snippet_hash},
                #{literal_value alt_options}

                );

        rb_define_method(plocals->self, #{real_method_name.to_s.inspect}, #{anonymous_method_name}, #{args_tree.size-1} );

        VALUE wrap_lambda = rb_eval_string(#{ruby_wrapper_code.inspect});
        rb_funcall(wrap_lambda, #{intern_num :call},1,plocals->self);

        "

    end

    def to_c_defs(tree)
      args_tree = tree[3];

      tmp = FastRuby.build_defs(tree)

      extra_code << tmp[0]
      @init_extra = @init_extra + tmp[2]

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
      "rb_gvar_defined((struct global_entry*)#{global_entry(tree[1][1])}) ? #{literal_value "global-variable"} : Qnil"
      elsif nt == :const
      "rb_const_defined(rb_cObject, #{intern_num tree[1][1]}) ? #{literal_value "constant"} : Qnil"
      elsif nt == :call
      "rb_method_node(CLASS_OF(#{to_c tree[1][1]}), #{intern_num tree[1][2]}) ? #{literal_value "method"} : Qnil"
      elsif nt == :yield
        "rb_block_given_p() ? #{literal_value "yield"} : Qnil"
      elsif nt == :ivar
      "rb_ivar_defined(plocals->self,#{intern_num tree[1][1]}) ? #{literal_value "instance-variable"} : Qnil"
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
        literal_value "assignment"
      else
        literal_value "expression"
      end
    end

    def initialize_method_structs(args_tree)
      @locals_struct = "struct {
        void* block_function_address;
        VALUE block_function_param;
        VALUE return_value;
        void* pframe;
        #{@locals.map{|l| "VALUE #{l};\n"}.join}
        #{args_tree[1..-1].map{|arg| "VALUE #{arg};\n"}.join};
        }"

      if @common_func
        init_extra << "
          #{@frame_struct} frame;
          #{@locals_struct} *plocals = malloc(sizeof(typeof(*plocals)));

          plocals->return_value = Qnil;
          plocals->pframe = &frame;
          plocals->self = rb_cObject;

          frame.target_frame = 0;
          frame.plocals = (void*)plocals;
          frame.return_value = Qnil;
          frame.exception = Qnil;
          frame.rescue = 0;
          frame.last_error = Qnil;
          frame.stack_chunk = 0;


          typeof(&frame) pframe = &frame;
        "
      end

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
          "plocals->#{arg} = #{arg};\n"
        }.join("") }

        plocals->block_function_address = block_address;
        plocals->block_function_param = block_param;

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

          frame.stack_chunk = 0;
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
            rb_funcall(self, #{intern_num :raise}, 1, frame.exception);
          }


          return #{@alt_method_name + "_real"}(#{strmethodargs});
      }
      "
    end

    def add_main
      if options[:main]

        extra_code << "
          static VALUE #{@alt_method_name}(VALUE self__);
          static VALUE main_proc_call(VALUE self__, VALUE class_self_) {
            #{@alt_method_name}(class_self_);
            return Qnil;
          }

        "

        init_extra << "
            {
            VALUE newproc = rb_funcall(rb_cObject,#{intern_num :new},0);
            rb_define_singleton_method(newproc, \"call\", main_proc_call, 1);
            rb_gv_set(\"$last_obj_proc\", newproc);

            }
          "
      end
    end

    def define_method_at_init(klass,method_name, size, signature)
      init_extra << "
        {
          VALUE method_name = rb_funcall(
                #{literal_value FastRuby},
                #{intern_num :make_str_signature},
                2,
                #{literal_value method_name},
                #{literal_value signature}
                );

          rb_define_method(#{literal_value klass}, RSTRING(method_name)->ptr, #{alt_method_name}, #{size});
        }
      "
    end

    def to_c_method(tree)
      method_name = tree[1]
      args_tree = tree[2]
      impl_tree = tree[3][1]

      if (options[:main])
        initialize_method_structs(args_tree)

        strargs = if args_tree.size > 1
          "VALUE block, VALUE _parent_frame, #{args_tree[1..-1].map{|arg| "VALUE #{arg}" }.join(",") }"
        else
          "VALUE block, VALUE _parent_frame"
        end

        ret = "VALUE #{@alt_method_name || method_name}() {

          #{@locals_struct} *plocals = malloc(sizeof(typeof(*plocals)));
          #{@frame_struct} frame;
          #{@frame_struct} *pframe;

          frame.stack_chunk = 0;
          frame.plocals = plocals;
          frame.parent_frame = 0;
          frame.return_value = Qnil;
          frame.target_frame = &frame;
          frame.exception = Qnil;
          frame.rescue = 0;

          plocals->pframe = &frame;

          pframe = (void*)&frame;

          VALUE last_expression = Qnil;

          int aux = setjmp(pframe->jmp);
          if (aux != 0) {

            if (pframe->target_frame == (void*)-2) {
              return pframe->return_value;
            }

            if (pframe->target_frame != pframe) {
              // raise exception
              return Qnil;
            }

            return plocals->return_value;
          }

          plocals->self = self;

          #{args_tree[1..-1].map { |arg|
            "plocals->#{arg} = #{arg};\n"
          }.join("") }

          plocals->block_function_address = 0;
          plocals->block_function_param = Qnil;

          return #{to_c impl_tree};
        }"

        add_main
        ret
      else

        initialize_method_structs(args_tree)

        strargs = if args_tree.size > 1
          "VALUE block, VALUE _parent_frame, #{args_tree[1..-1].map{|arg| "VALUE #{arg}" }.join(",") }"
        else
          "VALUE block, VALUE _parent_frame"
        end

        ret = "VALUE #{@alt_method_name || method_name}(#{strargs}) {

          #{@frame_struct} frame;
          #{@frame_struct} *pframe;

          frame.parent_frame = (void*)_parent_frame;
          frame.stack_chunk = ((typeof(pframe))_parent_frame)->stack_chunk;
          frame.return_value = Qnil;
          frame.target_frame = &frame;
          frame.exception = Qnil;
          frame.rescue = 0;

          int stack_chunk_instantiated = 0;
          VALUE previous_stack_chunk;
          VALUE current_thread = Qnil;
          VALUE rb_stack_chunk = Qnil;

          if (frame.stack_chunk == 0) {

            current_thread = rb_thread_current();
            previous_stack_chunk = rb_ivar_get(current_thread,#{intern_num :_fastruby_stack_chunk});
            rb_stack_chunk = previous_stack_chunk;

            if (rb_stack_chunk == Qnil) {
              rb_stack_chunk = rb_stack_chunk_create(Qnil);
              rb_gc_register_address(&rb_stack_chunk);
              stack_chunk_instantiated = 1;
              rb_ivar_set(current_thread,#{intern_num :_fastruby_stack_chunk},rb_stack_chunk);
            }

            Data_Get_Struct(rb_stack_chunk,void,frame.stack_chunk);
          }

          #{@locals_struct} *plocals;

          int previous_stack_position = stack_chunk_get_current_position(frame.stack_chunk);

          plocals = (typeof(plocals))stack_chunk_alloc(frame.stack_chunk ,sizeof(typeof(*plocals))/sizeof(void*));
          frame.plocals = plocals;
          plocals->pframe = &frame;

          pframe = (void*)&frame;

          #{@block_struct} *pblock;
          VALUE last_expression = Qnil;

          int aux = setjmp(pframe->jmp);
          if (aux != 0) {
            stack_chunk_set_current_position(frame.stack_chunk, previous_stack_position);

            if (stack_chunk_instantiated) {
              rb_gc_unregister_address(&rb_stack_chunk);
              rb_ivar_set(current_thread,#{intern_num :_fastruby_stack_chunk},previous_stack_chunk);
            }

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

          plocals->self = self;

          #{args_tree[1..-1].map { |arg|
            "plocals->#{arg} = #{arg};\n"
          }.join("") }

          pblock = (void*)block;
          if (pblock) {
            plocals->block_function_address = pblock->block_function_address;
            plocals->block_function_param = (VALUE)pblock->block_function_param;
          } else {
            plocals->block_function_address = 0;
            plocals->block_function_param = Qnil;
          }

          VALUE __ret = #{to_c impl_tree};
          stack_chunk_set_current_position(frame.stack_chunk, previous_stack_position);

          if (stack_chunk_instantiated) {
            rb_gc_unregister_address(&rb_stack_chunk);
            rb_ivar_set(current_thread,#{intern_num :_fastruby_stack_chunk},previous_stack_chunk);
          }

          return __ret;
        }"

        add_main
        ret
      end
    end

    def locals_accessor
      "plocals->"
    end

    def to_c_gvar(tree)
      "rb_gvar_get((struct global_entry*)#{global_entry(tree[1])})"
    end

    def to_c_gasgn(tree)
      "_rb_gvar_set((void*)#{global_entry(tree[1])}, #{to_c tree[2]})"
    end

    def to_c_ivar(tree)
      "rb_ivar_get(#{locals_accessor}self,#{intern_num tree[1]})"
    end

    def to_c_iasgn(tree)
      "_rb_ivar_set(#{locals_accessor}self,#{intern_num tree[1]},#{to_c tree[2]})"
    end

    def to_c_colon3(tree)
      "rb_const_get_from(rb_cObject, #{intern_num tree[1]})"
    end
    def to_c_colon2(tree)
      inline_block "
        VALUE klass = #{to_c tree[1]};

      if (rb_is_const_id(#{intern_num tree[2]})) {
        switch (TYPE(klass)) {
          case T_CLASS:
          case T_MODULE:
            return rb_const_get_from(klass, #{intern_num tree[2]});
            break;
          default:
            rb_raise(rb_eTypeError, \"%s is not a class/module\",
               RSTRING(rb_obj_as_string(klass))->ptr);
            break;
        }
      }
      else {
        return rb_funcall(klass, #{intern_num tree[2]}, 0, 0);
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
              if (CLASS_OF(arg)!=#{literal_value klass}) rb_raise(#{literal_value FastRuby::TypeMismatchAssignmentException}, \"Illegal assignment at runtime (type mismatch)\");
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

    def to_c_call(tree, repass_var = nil)
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
            pframe->exception = rb_funcall(#{to_c args[1]}, #{intern_num :exception},0);
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

        if repass_var
          extraargs = ","+repass_var
          extraargs_signature = ",VALUE " + repass_var
        else
          extraargs = ""
          extraargs_signature = ""
        end

          if argnum == 0
            value_cast = "VALUE,VALUE,VALUE"
            "((VALUE(*)(#{value_cast}))#{encode_address(recvtype,signature,mname,tree,inference_complete)})(#{to_c recv}, Qfalse, (VALUE)pframe)"
          else
            value_cast = ( ["VALUE"]*(args.size) ).join(",") + ",VALUE,VALUE"
            "((VALUE(*)(#{value_cast}))#{encode_address(recvtype,signature,mname,tree,inference_complete)})(#{to_c recv}, Qfalse, (VALUE)pframe, #{strargs})"
          end

      else # else recvtype
        if argnum == 0
          protected_block("rb_funcall(#{to_c recv}, #{intern_num tree[2]}, 0)", false, repass_var)
        else
          protected_block("rb_funcall(#{to_c recv}, #{intern_num tree[2]}, #{argnum}, #{strargs} )", false, repass_var)
        end
      end # if recvtype
    end

    def get_class_name(argument)
      if argument.instance_of? Symbol
        argument.to_s
      elsif argument.instance_of? FastRuby::FastRubySexp
        if argument[0] == :colon3
          get_class_name(argument[1])
        elsif argument[0] == :colon2
          get_class_name(argument[2])
        end
      end
    end

    def get_container_tree(argument)
      if argument.instance_of? Symbol
        s(:self)
      elsif argument.instance_of? FastRuby::FastRubySexp
        if argument[0] == :colon3
          s(:const, :Object)
        elsif argument[0] == :colon2
          argument[1]
        end
      end
    end

    def locals_scope(locals)
       old_locals = @locals
       old_locals_struct = @locals_struct

       @locals = locals
       @locals_struct = "struct {
        void* block_function_address;
        VALUE block_function_param;
        jmp_buf jmp;
        VALUE return_value;
        void* pframe;
        #{@locals.map{|l| "VALUE #{l};\n"}.join}
        }"

      begin
        yield
      ensure
        @locals = old_locals
        @locals_struct = old_locals_struct
      end
    end

    def method_group(init_code, tree)

      alt_locals = Set.new
      alt_locals << :self

      FastRuby::GetLocalsProcessor.get_locals(tree).each do |local|
        alt_locals << local
      end

      fun = nil

      locals_scope(alt_locals) do
        fun = anonymous_function { |method_name| "static VALUE #{method_name}(VALUE self) {

            #{@frame_struct} frame;
            typeof(&frame) pframe = &frame;
            #{@locals_struct} *plocals = malloc(sizeof(typeof(*plocals)));

            frame.stack_chunk = 0;
            frame.plocals = plocals;
            frame.parent_frame = 0;
            frame.return_value = Qnil;
            frame.target_frame = &frame;
            frame.exception = Qnil;
            frame.rescue = 0;

            plocals->self = self;

            #{to_c tree};
            return Qnil;
          }
        "
        }
      end

      inline_block("
        #{init_code}

        rb_funcall(tmpklass, #{intern_num :__id__},0);

        #{fun}(tmpklass);
        return Qnil;


      ")

    end



    def to_c_class(tree)
      str_class_name = get_class_name(tree[1])
      container_tree = get_container_tree(tree[1])

      if container_tree == s(:self)
        method_group("
                    VALUE tmpklass = rb_define_class(
                      #{str_class_name.inspect},
                      #{tree[2] ? to_c(tree[2]) : "rb_cObject"}
                  );
        ", tree[3])
      else
        method_group("
                    VALUE container_klass = #{to_c(container_tree)};
                    VALUE tmpklass = rb_define_class_under(
                      container_klass,
                      #{str_class_name.inspect},
                      #{tree[2] ? to_c(tree[2]) : "rb_cObject"}
                  );
        ", tree[3])
      end
    end

    def to_c_module(tree)
      str_class_name = get_class_name(tree[1])
      container_tree = get_container_tree(tree[1])

      if container_tree == s(:self)
        method_group("
                      VALUE tmpklass = rb_define_module(#{str_class_name.inspect});
        ", tree[2])
      else
        method_group("
                      VALUE container_klass = #{to_c(container_tree)};
                      VALUE tmpklass = rb_define_module_under(container_klass,#{str_class_name.inspect});
        ", tree[2])
      end
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

        unless (args[2] == s(:false))
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
          code
        end

      else
        nil
      end
    end

    def inline_block_reference(arg)
      code = nil

      if arg.instance_of? FastRuby::FastRubySexp
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

    def inline_block(code, repass_var = nil)
      anonymous_function{ |name| "
        static VALUE #{name}(VALUE param#{repass_var ? ",void* " + repass_var : "" }) {
          #{@frame_struct} *pframe = (void*)param;
          #{@locals_struct} *plocals = (void*)pframe->plocals;
          VALUE last_expression = Qnil;

          #{code}
          }
        "
      } + "((VALUE)pframe#{repass_var ? ", " + repass_var : "" })"
    end

    def inline_ruby(proced, parameter)
      "rb_funcall(#{proced.__id__}, #{intern_num :call}, 1, #{parameter})"
    end

    def wrapped_break_block(inner_code)
      frame("return " + inner_code, "
            if (original_frame->target_frame == (void*)-2) {
              return pframe->return_value;
            }
            ")
    end

    def protected_block(inner_code, always_rescue = false,repass_var = nil)
      wrapper_code = "
         if (pframe->last_error != Qnil) {
              if (CLASS_OF(pframe->last_error)==#{literal_value FastRuby::Context::UnwindFastrubyFrame}) {
              #{@frame_struct} *pframe = (void*)param;

                pframe->target_frame = (void*)FIX2LONG(rb_ivar_get(pframe->last_error, #{intern_num :@target_frame}));
                pframe->exception = rb_ivar_get(pframe->last_error, #{intern_num :@ex});
                pframe->return_value = rb_ivar_get(pframe->last_error, #{intern_num :@return_value});

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


      body = nil
      rescue_args = nil
      if repass_var
        body =  anonymous_function{ |name| "
          static VALUE #{name}(VALUE param) {
            #{@frame_struct} *pframe = ((void**)param)[0];
            #{@locals_struct} *plocals = pframe->plocals;
            VALUE #{repass_var} = (VALUE)((void**)param)[1];
            return #{inner_code};
            }
          "
        }

        rescue_args = ""
        rescue_args = "(VALUE)(VALUE[]){(VALUE)pframe,(VALUE)#{repass_var}}"
      else
        body = inline_block_reference("return #{inner_code}")
        rescue_args = "(VALUE)pframe"
      end

      rescue_code = "rb_rescue2(#{body},#{rescue_args},#{anonymous_function{|name| "
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
        ", repass_var
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
        ", repass_var
      end

    end


    def func_frame
      "
        #{@locals_struct} *plocals = malloc(sizeof(typeof(*plocals)));
        #{@frame_struct} frame;
        #{@frame_struct} *pframe;

        frame.plocals = plocals;
        frame.parent_frame = (void*)_parent_frame;
        frame.stack_chunk = ((typeof(pframe))_parent_frame)->stack_chunk;
        frame.return_value = Qnil;
        frame.target_frame = &frame;
        frame.exception = Qnil;
        frame.rescue = 0;

        plocals->pframe = &frame;

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

        plocals->self = self;
      "
    end

    def c_escape(str)
      str.inspect
    end

    def literal_value(value)
      @literal_value_hash = Hash.new unless @literal_value_hash
      return @literal_value_hash[value] if @literal_value_hash[value]

      name = self.add_global_name("VALUE", "Qnil");

      begin

        str = Marshal.dump(value)


        if value.instance_of? Module

          container_str = value.to_s.split("::")[0..-2].join("::")

          init_extra << "
            #{name} = rb_define_module_under(
                    #{container_str == "" ? "rb_cObject" : literal_value(eval(container_str))}
                    ,\"#{value.to_s.split("::").last}\");

            rb_funcall(#{name},#{intern_num :gc_register_object},0);
          "
        elsif value.instance_of? Class
          container_str = value.to_s.split("::")[0..-2].join("::")

          init_extra << "
            #{name} = rb_define_class_under(
                    #{container_str == "" ? "rb_cObject" : literal_value(eval(container_str))}
                    ,\"#{value.to_s.split("::").last}\"
                    ,#{value.superclass == Object ? "rb_cObject" : literal_value(value.superclass)});

            rb_funcall(#{name},#{intern_num :gc_register_object},0);
          "
        elsif value.instance_of? Array
          init_extra << "
            #{name} = rb_ary_new3(#{value.size}, #{value.map{|x| literal_value x}.join(",")} );
            rb_funcall(#{name},#{intern_num :gc_register_object},0);
          "
        else

          init_extra << "
            #{name} = rb_marshal_load(rb_str_new(#{c_escape str}, #{str.size}));
            rb_funcall(#{name},#{intern_num :gc_register_object},0);

          "
        end
      rescue TypeError => e
        @no_cache = true
        FastRuby.logger.info "#{value} disabling cache for extension"
        init_extra << "
          #{name} = rb_funcall(rb_const_get(rb_cObject, #{intern_num :ObjectSpace}), #{intern_num :_id2ref}, 1, INT2FIX(#{value.__id__}));
        "

      end
     @literal_value_hash[value] = name

      name
    end

    def encode_address(recvtype,signature,mname,call_tree,inference_complete,convention_global_name = nil)
      name = self.add_global_name("void*", 0);
      cruby_name = self.add_global_name("void*", 0);
      cruby_len = self.add_global_name("int", 0);
      args_tree = call_tree[3]
      method_tree = nil

      begin
        method_tree = recvtype.instance_method(@method_name.to_sym).fastruby.tree
      rescue NoMethodError
      end


      strargs_signature = (0..args_tree.size-2).map{|x| "VALUE arg#{x}"}.join(",")
      strargs = (0..args_tree.size-2).map{|x| "arg#{x}"}.join(",")
      inprocstrargs = (1..args_tree.size-1).map{|x| "((VALUE*)method_arguments)[#{x}]"}.join(",")

      if args_tree.size > 1
        strargs_signature = "," + strargs_signature
        toprocstrargs = "self,"+strargs
        strargs = "," + strargs
        inprocstrargs = ","+inprocstrargs
      else
        toprocstrargs = "self"
      end

      ruby_wrapper = anonymous_function{ |funcname| "
        static VALUE #{funcname}(VALUE self,void* block,void* frame#{strargs_signature}){
          #{@frame_struct}* pframe = frame;

          VALUE method_arguments[#{args_tree.size}] = {#{toprocstrargs}};

          return #{
            protected_block "rb_funcall(((VALUE*)method_arguments)[0], #{intern_num mname.to_sym}, #{args_tree.size-1}#{inprocstrargs});", false, "method_arguments"
            };
        }
        "
      }

      value_cast = ( ["VALUE"]*(args_tree.size) ).join(",")

      cruby_wrapper = anonymous_function{ |funcname| "
        static VALUE #{funcname}(VALUE self,void* block,void* frame#{strargs_signature}){
          #{@frame_struct}* pframe = frame;

          VALUE method_arguments[#{args_tree.size}] = {#{toprocstrargs}};

          // call to #{recvtype}::#{mname}

          if (#{cruby_len} == -1) {
            return #{
              protected_block "((VALUE(*)(int,VALUE*,VALUE))#{cruby_name})(#{args_tree.size-1}, ((VALUE*)method_arguments)+1,*((VALUE*)method_arguments));", false, "method_arguments"
              };

          } else if (#{cruby_len} == -2) {
            return #{
              protected_block "((VALUE(*)(VALUE,VALUE))#{cruby_name})(*((VALUE*)method_arguments), rb_ary_new4(#{args_tree.size-1},((VALUE*)method_arguments)+1) );", false, "method_arguments"
              };

          } else {
            return #{
              protected_block "((VALUE(*)(#{value_cast}))#{cruby_name})(((VALUE*)method_arguments)[0] #{inprocstrargs});", false, "method_arguments"
              };
          }
        }
        "
      }

      recvdump = nil

      begin
         recvdump = literal_value recvtype
      rescue
      end

      if recvdump and recvtype
        init_extra << "
          {
            VALUE recvtype = #{recvdump};
            rb_funcall(#{literal_value FastRuby}, #{intern_num :set_builder_module}, 1, recvtype);
            VALUE signature = #{literal_value signature};
            VALUE mname = #{literal_value mname};
            VALUE tree = #{literal_value method_tree};
            VALUE convention = rb_funcall(recvtype, #{intern_num :convention}, 3,signature,mname,#{inference_complete ? "Qtrue" : "Qfalse"});
            VALUE mobject = rb_funcall(recvtype, #{intern_num :method_from_signature},3,signature,mname,#{inference_complete ? "Qtrue" : "Qfalse"});

            struct METHOD {
              VALUE klass, rklass;
              VALUE recv;
              ID id, oid;
              int safe_level;
              NODE *body;
            };

            int len = 0;
            void* address = 0;

            if (mobject != Qnil) {

              struct METHOD *data;
              Data_Get_Struct(mobject, struct METHOD, data);

              if (nd_type(data->body) == NODE_CFUNC) {
              address = data->body->nd_cfnc;
              len = data->body->nd_argc;
              }
            }

            #{convention_global_name ? convention_global_name + " = 0;" : ""}
            if (recvtype != Qnil) {

              if (convention == #{literal_value :fastruby}) {
                #{convention_global_name ? convention_global_name + " = 1;" : ""}
                #{name} = address;
              } else if (convention == #{literal_value :cruby}) {
                // cruby, wrap direct call
                #{cruby_name} = address;

                if (#{cruby_name} == 0) {
                  #{name} = (void*)#{ruby_wrapper};
                } else {
                  #{cruby_len} = len;
                  #{name} = (void*)#{cruby_wrapper};
                }
              } else {
                // ruby, wrap rb_funcall
                #{name} = (void*)#{ruby_wrapper};
              }
            } else {
              // ruby, wrap rb_funcall
              #{name} = (void*)#{ruby_wrapper};
            }

          }
        "
      else
        init_extra << "
        // ruby, wrap rb_funcall
        #{name} = (void*)#{ruby_wrapper};
        "
      end

      name
    end

    def intern_num(symbol)
      @intern_num_hash = Hash.new unless @intern_num_hash
      return @intern_num_hash[symbol] if @intern_num_hash[symbol]

      name = self.add_global_name("ID", 0);

      init_extra << "
        #{name} = rb_intern(\"#{symbol.to_s}\");
      "

      @intern_num_hash[symbol] = name

      name
    end

    def add_global_name(ctype, default)
      name = "glb" + rand(1000000000).to_s

      extra_code << "
        static #{ctype} #{name} = #{default};
      "
      name
    end

    def global_entry(glbname)
      name = add_global_name("struct global_entry*", 0);

      init_extra << "
        #{name} = rb_global_entry(SYM2ID(#{literal_value glbname}));
      "

      name
    end


    def frame(code, jmp_code, not_jmp_code = "", rescued = nil)

      anonymous_function{ |name| "
        static VALUE #{name}(VALUE param) {
          VALUE last_expression;
          #{@frame_struct} frame, *pframe, *parent_frame;
          #{@locals_struct} *plocals;

          parent_frame = (void*)param;

          frame.stack_chunk = parent_frame->stack_chunk;
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
  end
end
