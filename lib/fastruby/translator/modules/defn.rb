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
      
      strmethodargs = "self,block,(VALUE)&frame"
      
      anonymous_method_name = anonymous_function{ |anonymous_method_name| "VALUE #{anonymous_method_name}(int argc_, VALUE* argv, VALUE self) {
          VALUE klass = #{global_klass_variable};
          char method_name[0x100];

          method_name[0] = '_';
          method_name[1] = 0;

          sprintf(method_name+1, \"#{method_name}\");
          sprintf(method_name+strlen(method_name), \"%lu\", FIX2LONG(rb_obj_id(CLASS_OF(self))));
          
                      int i;
                      for (i=0; i<argc_; i++) {
                        sprintf(method_name+strlen(method_name), \"%lu\", FIX2LONG(rb_obj_id(CLASS_OF(argv[i]))));
                      }

          void** address = 0;
          void* fptr = 0;
          ID id;
          VALUE rb_method_hash;

          id = rb_intern(method_name);
          rb_method_hash = rb_funcall(klass, #{intern_num :method_hash},1,#{literal_value method_name});
          
          if (rb_method_hash != Qnil) {
            VALUE tmp = rb_hash_aref(rb_method_hash, LONG2FIX(id));
            if (tmp != Qnil) {
                address = (void**)FIX2LONG(tmp);
                fptr = *address;
            }
          }

          if (fptr == 0) {
                          VALUE argv_class[argc_+1];
                          
                          argv_class[0] = CLASS_OF(self); 
                          for (i=0; i<argc_; i++) {
                            argv_class[i+1] = CLASS_OF(argv[i]);
                          }
                          
                          VALUE signature = rb_ary_new4(argc_+1,argv_class);
            
            rb_funcall(#{global_klass_variable}, #{intern_num :build}, 2, signature,rb_str_new2(#{method_name.to_s.inspect}));
  
            id = rb_intern(method_name);
            rb_method_hash = rb_funcall(klass, #{intern_num :method_hash},1,#{literal_value method_name});
            
            if (rb_method_hash != Qnil) {
              VALUE tmp = rb_hash_aref(rb_method_hash, LONG2FIX(id));
              if (tmp != Qnil) {
                  address = (void**)FIX2LONG(tmp);
                  fptr = *address;
              }
            }
            
            if (fptr == 0) {
              rb_raise(rb_eRuntimeError, \"Error: method not found after build\");
            }

          }

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

                  if (argc_ == 0) return ((VALUE(*)(VALUE,VALUE,VALUE))fptr)(#{strmethodargs});
                    
                  #{ (1..9).map{ |i|
                    value_cast = ( ["VALUE"]*(i+3) ).join(",")
                    "if (argc_ == #{i}) return ((VALUE(*)(#{value_cast}))fptr)(#{strmethodargs}, #{(0..i-1).map{|x| "argv[#{x}]"}.join(",")});"
                    }.join("\n");
                  }

          return Qnil;
        }"
      }

      alt_options = options.dup

      alt_options.delete(:self)
      alt_options.delete(:main)

      inline_block "
        rb_define_method(plocals->self, #{method_name.to_s.inspect}, #{anonymous_method_name}, -1 );
        
        #{global_klass_variable} = plocals->self;
        // set tree
        rb_funcall(#{literal_value FastRuby}, #{intern_num :set_tree}, 5,
                #{global_klass_variable},
                rb_str_new2(#{method_name.to_s.inspect}),
                #{literal_value tree},
                #{literal_value snippet_hash},
                #{literal_value alt_options}

                );

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
