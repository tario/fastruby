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
require "fastruby/translator/translator_modules"
require "rubygems"
require "sexp"

module FastRuby
  module DefnTranslator
    register_translator_module self

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

      anonymous_method_name = anonymous_function{ |anonymous_method_name| "VALUE #{anonymous_method_name}(#{(["self"]+args_tree[1..-1]).map{|arg| "VALUE #{arg}" }.join(",")}) {

          VALUE klass = #{global_klass_variable};
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
                void* plocals;
                jmp_buf jmp;
                VALUE return_value;
                int rescue;
                VALUE last_error;
                VALUE next_recv;
                int targetted;
                struct FASTRUBYTHREADDATA* thread_data;
              } frame;

              frame.parent_frame = 0;
              frame.rescue = 0;
              frame.return_value = Qnil;
              frame.thread_data = rb_current_thread_data();
              frame.targetted = 0;

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
                if (aux == FASTRUBY_TAG_RAISE) {
                  rb_funcall(self, #{intern_num :raise}, 1, frame.thread_data->exception);
                }

                if (frame.targetted == 0) {
                    rb_jump_tag(aux);
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

        rb_define_method(plocals->self, #{method_name.to_s.inspect}, #{anonymous_method_name}, #{args_tree.size-1} );
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
    
  end
end
