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

    define_translator_for(:class, :method => :to_c_class)
    def to_c_class(tree, result_var = nil)
      str_class_name = get_class_name(tree[1])
      container_tree = get_container_tree(tree[1])

      if container_tree == s(:self)
        method_group("
                    VALUE superklass = rb_cObject;
                    #{
                    if tree[2] 
                      to_c tree[2], "superklass"
                    end
                    };
                    VALUE tmpklass = rb_define_class(
                      #{str_class_name.inspect},
                      superklass
                  );
        ", tree[3], result_var)
      else
        method_group("
                    VALUE container_klass = Qnil;
                    VALUE superklass = rb_cObject;
                    
                    #{
                    if tree[2] 
                      to_c tree[2], "superklass"
                    end
                    };
                    
                    #{to_c(container_tree, "container_klass")};
                    VALUE tmpklass = rb_define_class_under(
                      container_klass,
                      #{str_class_name.inspect},
                      superklass
                  );
        ", tree[3], result_var)
      end
    end

    define_translator_for(:module, :method => :to_c_module)
    def to_c_module(tree, result_var = nil)
      str_class_name = get_class_name(tree[1])
      container_tree = get_container_tree(tree[1])

      if container_tree == s(:self)
        method_group("
                      VALUE tmpklass = rb_define_module(#{str_class_name.inspect});
        ", tree[2], result_var)
      else
        method_group("
                      VALUE container_klass = Qnil;
                      
                      #{to_c(container_tree, "container_klass")};
                      VALUE tmpklass = rb_define_module_under(container_klass,#{str_class_name.inspect});
        ", tree[2], result_var)
      end
    end
    
private
    def method_group(init_code, tree, result_var)

      alt_locals = Set.new
      alt_locals << :self

      FastRuby::GetLocalsProcessor.get_locals(tree).each do |local|
        alt_locals << local
      end

      code = proc{ 
      fun = nil
      locals_scope(alt_locals) do
        fun = anonymous_function { |method_name| "static VALUE #{method_name}(VALUE self) {

            #{@frame_struct} frame;
            typeof(&frame) pframe = &frame;
            #{@locals_struct} *plocals;

            frame.parent_frame = 0;
            frame.return_value = Qnil;
            frame.rescue = 0;
            frame.targetted = 0;
            frame.thread_data = rb_current_thread_data();

            int stack_chunk_instantiated = 0;
            VALUE rb_previous_stack_chunk = Qnil;
            VALUE rb_stack_chunk = frame.thread_data->rb_stack_chunk;
            struct STACKCHUNK* stack_chunk = 0;

            if (rb_stack_chunk != Qnil) {
              Data_Get_Struct(rb_stack_chunk,struct STACKCHUNK,stack_chunk);
            }

            if (stack_chunk == 0 || (stack_chunk == 0 ? 0 : stack_chunk_frozen(stack_chunk)) ) {
              rb_previous_stack_chunk = rb_stack_chunk;
              rb_gc_register_address(&rb_stack_chunk);
              stack_chunk_instantiated = 1;

              rb_stack_chunk = rb_stack_chunk_create(Qnil);
              frame.thread_data->rb_stack_chunk = rb_stack_chunk;

              rb_ivar_set(rb_stack_chunk, #{intern_num :_parent_stack_chunk}, rb_previous_stack_chunk);

              Data_Get_Struct(rb_stack_chunk,struct STACKCHUNK,stack_chunk);
            }

            int previous_stack_position = stack_chunk_get_current_position(stack_chunk);

            plocals = (typeof(plocals))stack_chunk_alloc(stack_chunk ,sizeof(typeof(*plocals))/sizeof(void*));

            plocals->parent_locals = frame.thread_data->last_plocals;
            void* old_parent_locals = frame.thread_data->last_plocals;
            frame.thread_data->last_plocals = plocals;

            frame.plocals = plocals;
            plocals->active = Qtrue;
            plocals->self = self;
            plocals->targetted = Qfalse;
            plocals->call_frame = 0;

            #{to_c tree};

            stack_chunk_set_current_position(stack_chunk, previous_stack_position);

            if (stack_chunk_instantiated) {
              rb_gc_unregister_address(&rb_stack_chunk);
              frame.thread_data->rb_stack_chunk = rb_previous_stack_chunk;
            }

            plocals->active = Qfalse;
            
            frame.thread_data->last_plocals = old_parent_locals;
            
            return Qnil;
          }
        "
        }
      end
      
      "
        {
        #{init_code}

        rb_funcall(tmpklass, #{intern_num :__id__},0);

        #{fun}(tmpklass);
        }
      "
      }
      
      if result_var
        code.call + "\n#{result_var} = Qnil;\n"
      else  
        inline_block &code + "\nreturn Qnil;\n"
      end
      
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
  end
end
