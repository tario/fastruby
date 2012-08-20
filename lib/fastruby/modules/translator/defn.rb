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
  class Context
    
    define_translator_for(:defn, :method => :to_c_defn)
    def to_c_defn(tree, result_var = nil)

      method_name = tree[1]
      args_tree = tree[2].select{|x| x.to_s[0] != ?&}
      
      global_klass_variable = add_global_name("VALUE", "Qnil");

      hash = Hash.new
      value_cast = ( ["VALUE"]*(args_tree.size+2) ).join(",")
      
      strmethodargs = "self,block,(VALUE)&frame"
      
      anonymous_method_name = anonymous_dispatcher(global_klass_variable, method_name)
      alt_options = options.dup

      alt_options.delete(:self)
      alt_options.delete(:main)

      code = "
      
      
        if (rb_obj_is_kind_of(#{locals_accessor}self, rb_cClass) || rb_obj_is_kind_of(#{locals_accessor}self, rb_cModule)) {

          #{unless options[:fastruby_only]
           "rb_define_method(plocals->self, #{method_name.to_s.inspect}, #{anonymous_method_name}, -1);"
          end
          }
          
          #{global_klass_variable} = #{locals_accessor}self;
          // set tree
          rb_funcall(#{literal_value FastRuby}, #{intern_num :set_tree}, 4,
                  #{global_klass_variable},
                  rb_str_new2(#{method_name.to_s.inspect}),
                  #{literal_value tree},
                  #{literal_value alt_options}
  
                  );
          
        } else {
          VALUE obj = #{locals_accessor}self;
          rb_define_singleton_method(obj, #{method_name.to_s.inspect}, #{anonymous_method_name}, -1 );
          
          #{global_klass_variable} = CLASS_OF(obj);
          // set tree
          rb_funcall(#{literal_value FastRuby}, #{intern_num :set_tree}, 4,
                  #{global_klass_variable},
                  rb_str_new2(#{method_name.to_s.inspect}),
                  #{literal_value tree},
                  #{literal_value alt_options}
  
                  );
        }
        
        "

      if result_var
        code + "\n#{result_var} = Qnil;"
      else
        inline_block code + "\nreturn Qnil;\n"
      end
    end

    define_translator_for(:defs, :method => :to_c_defs)
    def to_c_defs(tree, result_var = nil)
      method_name = tree[2]
      args_tree = tree[3].select{|x| x.to_s[0] != ?&}
      
      global_klass_variable = add_global_name("VALUE", "Qnil");

      hash = Hash.new
      value_cast = ( ["VALUE"]*(args_tree.size+2) ).join(",")
      
      strmethodargs = "self,block,(VALUE)&frame"
      
      anonymous_method_name = anonymous_dispatcher(global_klass_variable, method_name)

      alt_options = options.dup

      alt_options.delete(:self)
      alt_options.delete(:main)

      code = "
      
        VALUE obj = Qnil;
        #{to_c tree[1], "obj"};
        rb_define_singleton_method(obj, #{method_name.to_s.inspect}, #{anonymous_method_name}, -1 );
        
        #{global_klass_variable} = CLASS_OF(obj);
        // set tree
        rb_funcall(#{literal_value FastRuby}, #{intern_num :set_tree}, 4,
                #{global_klass_variable},
                rb_str_new2(#{method_name.to_s.inspect}),
                #{literal_value tree},
                #{literal_value alt_options}

                );

        "

      if result_var
        code + "\n#{result_var} = Qnil;"
      else
        inline_block code + "\nreturn Qnil;\n"
      end
        
    end

    define_translator_for(:scope, :method => :to_c_scope)
    def to_c_scope(tree, result_var = nil)
      if tree[1]
        if result_var
          to_c(tree[1], result_var)
        else
          to_c(tree[1])
        end
      else
        "Qnil"
      end
    end
    
private
 
    def anonymous_dispatcher(global_klass_variable, method_name)
      
      strmethodargs = "self,block,(VALUE)&frame"
      nilsignature = [nil]*32      

      anonymous_function{ |anonymous_method_name| "VALUE #{anonymous_method_name}(int argc_, VALUE* argv, VALUE self) {
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

          volatile VALUE block = Qfalse;

          if (rb_block_given_p()) {
            struct {
              void* block_function_address;
              void* block_function_param;
              VALUE proc;
            } block_struct;

            block_struct.block_function_address = re_yield;
            block_struct.block_function_param = 0;
            block_struct.proc = rb_block_proc();

            block = (VALUE)&block_struct;
          }


          int aux = setjmp(frame.jmp);
          if (aux != 0) {
            if (aux == FASTRUBY_TAG_RAISE) {
              rb_funcall(self, #{intern_num :raise}, 1, frame.thread_data->exception);
            }

            if (frame.targetted == 0) {
              frb_jump_tag(aux);
            }

            return Qnil;
          }
              
          VALUE tmp = Qnil;
          if (argv == 0) argv = &tmp;

          return #{dynamic_call(nilsignature, method_name.to_sym, false, false, global_klass_variable)}(self, (void*)block, (void*)&frame, argc_, argv);
        }"
      }

      
    end
  end
end
