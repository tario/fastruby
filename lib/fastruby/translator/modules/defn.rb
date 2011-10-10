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
module FastRuby
  module DefnTranslator
    register_translator_module self

    def to_c_defn(tree)

      method_name = tree[1]
      args_tree = tree[2]

      global_klass_variable = add_global_name("VALUE", "Qnil");

      hash = Hash.new
      value_cast = ( ["VALUE"]*(args_tree.size+2) ).join(",")
      
      multiple_arguments = args_tree[1..-1].find{|x| x.to_s =~ /\*/}
      
      args_array_accessors = if multiple_arguments
        (0..args_tree.size-3).map{|x| "argv[#{x}]"} + ["argarray"]
      else
        (0..args_tree.size-2).map{|x| "argv[#{x}]"}
      end
      
      strmethodargs = ""

      if args_tree.size > 1
        strmethodargs = "self,block,(VALUE)&frame,#{args_array_accessors.map(&:to_s).join(",") }"
      else
        strmethodargs = "self,block,(VALUE)&frame"
      end
      
      strmakesignature = if multiple_arguments
                          "
                          VALUE argv_class[argc_+1];
                          
                          argv_class[0] = CLASS_OF(self); 
                          for (i=0; i<#{args_tree.size-2}; i++) {
                            argv_class[i+1] = CLASS_OF(argv[i]);
                          }
                          
                          argv_class[#{args_tree.size-1}] = rb_cArray;
                          
                          VALUE signature = rb_ary_new4(#{args_tree.size},argv_class);
                          "
                       else
                           "
                          VALUE argv_class[argc_+1];
                          
                          argv_class[0] = CLASS_OF(self); 
                          for (i=0; i<argc_; i++) {
                            argv_class[i+1] = CLASS_OF(argv[i]);
                          }
                          
                          VALUE signature = rb_ary_new4(argc_+1,argv_class);
                          "
                        end                           
      
      strmakemethodsignature = if multiple_arguments
                    "
                      int i;
                      for (i=0; i<#{args_tree.size-2}; i++) {
                        sprintf(method_name+strlen(method_name), \"%lu\", FIX2LONG(rb_obj_id(CLASS_OF(argv[i]))));
                      }
                      sprintf(method_name+strlen(method_name), \"%lu\", FIX2LONG(rb_obj_id(rb_cArray)));
                    "
                  else
                    "
                      int i;
                      for (i=0; i<argc_; i++) {
                        sprintf(method_name+strlen(method_name), \"%lu\", FIX2LONG(rb_obj_id(CLASS_OF(argv[i]))));
                      }
                    "                      
                  end
                  
      strrequiredargs = if multiple_arguments
                          args_tree.size-2
                        else
                          args_tree.size-1
                        end                  
                   
      strmakecall = if multiple_arguments
                "
                  if (argc_ > #{args_tree.size-2}) {
                    VALUE argarray = rb_ary_new4(argc_-#{args_tree.size-2}, argv+#{args_tree.size-2});
                    return ((VALUE(*)(#{value_cast}))body->nd_cfnc)(#{strmethodargs});
                  } else if (argc_ == #{args_tree.size-2}) {
                    // pass pre-calculated method arguments plus an empty array
                    VALUE argarray = rb_ary_new();
                    return ((VALUE(*)(#{value_cast}))body->nd_cfnc)(#{strmethodargs});
                  } else {
                    rb_raise(rb_eArgError, \"wrong number of arguments (%d for #{args_tree.size-2}))\", argc_);
                  }
                "
              else
                "if (argc_ == #{args_tree.size-1} && argc == #{args_tree.size+1}) {
                  return ((VALUE(*)(#{value_cast}))body->nd_cfnc)(#{strmethodargs});
                } else {
                  rb_raise(rb_eArgError, \"wrong number of arguments (%d for #{args_tree.size-1}))\", argc_);
                }"
              end

      anonymous_method_name = anonymous_function{ |anonymous_method_name| "VALUE #{anonymous_method_name}(int argc_, VALUE* argv, VALUE self) {
      
          if (argc_ < #{strrequiredargs}) {
            rb_raise(rb_eArgError, \"wrong number of arguments (%d for #{strrequiredargs}))\", argc_);
          }

          VALUE klass = #{global_klass_variable};
          char method_name[0x100];

          method_name[0] = '_';
          method_name[1] = 0;

          sprintf(method_name+1, \"#{method_name}\");
          sprintf(method_name+strlen(method_name), \"%lu\", FIX2LONG(rb_obj_id(CLASS_OF(self))));
          
          #{strmakemethodsignature}

          NODE* body;
          ID id;

          id = rb_intern(method_name);
          body = rb_method_node(klass,id);

          if (body == 0) {
            
            #{strmakesignature}
            
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

              #{strmakecall}
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

        rb_define_method(plocals->self, #{method_name.to_s.inspect}, #{anonymous_method_name}, -1 );
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

    def to_c_scope(tree)
      if tree[1]
        to_c(tree[1])
      else
        "Qnil"
      end
    end
  end
end
