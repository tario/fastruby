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
  module IterTranslator
    
    register_translator_module IterTranslator

    def to_c_iter(tree, result_var = nil)

      call_tree = tree[1]
      args_tree = tree[2]
      recv_tree = call_tree[1]

      directive_code = directive(call_tree)
      if directive_code
        if result_var
          return "#{result_var} = #{directive_code};\n"
        else
          return directive_code
        end
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
      end

      anonymous_impl = tree[3]

      str_lvar_initialization = "#{@frame_struct} *pframe;
                                 #{@locals_struct} *plocals;
                                pframe = (void*)param;
                                plocals = (void*)pframe->plocals;
                                "

      str_arg_initialization = ""

      str_impl = ""
      on_block do
        str_impl = to_c(anonymous_impl, "last_expression")
      end     

        if not args_tree
        elsif args_tree.first == :lasgn
          if RUBY_VERSION =~ /^1\.8/
            str_arg_initialization << "plocals->#{args_tree[1]} = arg;"
          elsif RUBY_VERSION =~ /^1\.9/
            str_arg_initialization << "
              if (TYPE(arg) != T_ARRAY) {
                plocals->#{args_tree[1]} = arg;
              } else {
                plocals->#{args_tree[1]} = rb_ary_entry(arg,0);
              }
              "
          end
        elsif args_tree.first == :masgn
          
          if RUBY_VERSION =~ /^1\.8/
            str_arg_initialization << "
                {
                  if (TYPE(arg) != T_ARRAY) {
                    if (arg != Qnil) {
                      arg = rb_ary_new4(1,&arg);
                    } else {
                      arg = rb_ary_new2(0);
                    }
                  } else if (_RARRAY_LEN(arg) <= 1) {
                    arg = rb_ary_new4(1,&arg);
                  }
                }
                "
          elsif RUBY_VERSION =~ /^1\.9/
            str_arg_initialization << "
                {
                }
                "
          end
          
          arguments = args_tree[1][1..-1]
          
          (0..arguments.size-1).each do |i|
            arg = arguments[i]
            if arg[0] == :lasgn 
              str_arg_initialization << "plocals->#{arguments[i].last} = rb_ary_entry(arg,#{i});\n"
            elsif arg[0] == :splat
              str_arg_initialization << "plocals->#{arg.last.last} = rb_ary_new2(_RARRAY_LEN(arg)-#{i});\n
              
                int i;
                for (i=#{i};i<_RARRAY_LEN(arg);i++){
                  rb_ary_store(plocals->#{arg.last.last},i-#{i},rb_ary_entry(arg,i));
                }
               "
            end
          end
        end
        rb_funcall_caller_code = nil

        if call_args_tree.size > 1

          str_recv = "pframe->next_recv"

          str_recv = "plocals->self" unless recv_tree
            if call_args_tree.last[0] == :splat
              rb_funcall_caller_code = proc { |name| "
                static VALUE #{name}(VALUE param) {
                  // call to #{call_tree[2]}
  
                  VALUE last_expression = Qnil;
                  #{str_lvar_initialization}
                  
                  VALUE array = Qnil;
                  
                  #{to_c call_args_tree.last[1], "array"};
                  
                  if (TYPE(array) != T_ARRAY) {
                    array = rb_ary_new4(1,&array);
                  }
                  
                  int argc = #{call_args_tree.size-2};
                  VALUE argv[#{call_args_tree.size} + _RARRAY_LEN(array)];
                  
                  VALUE aux_ = Qnil;;
                  #{
                    i = -1
                    call_args_tree[1..-2].map {|arg|
                      i = i + 1
                      "
                      #{to_c arg, "aux_"};
                      argv[#{i}] = aux_;
                      "
                    }.join(";\n")
                  };
                  
                  int array_len = _RARRAY_LEN(array);
                  
                  int i;
                  for (i=0; i<array_len;i++) {
                    argv[argc] = rb_ary_entry(array,i);
                    argc++; 
                  }
                  
                  return rb_funcall2(#{str_recv}, #{intern_num call_tree[2]}, argc, argv);
                }
              "
              }
            else
              str_evaluate_args = "
                  #{
                    (0..call_args_tree.size-2).map{|i|
                      "VALUE arg#{i} = Qnil;"
                    }.join("\n")
                  }
                  
                  #{
                    (0..call_args_tree.size-2).map{|i|
                      to_c(call_args_tree[i+1], "arg#{i}")+";"
                    }.join("\n")
                  }
              "
              rb_funcall_caller_code = proc { |name| "
                static VALUE #{name}(VALUE param) {
                  // call to #{call_tree[2]}
                  VALUE last_expression = Qnil;
  
                  #{str_lvar_initialization}
                  
                  #{str_evaluate_args};
                  
                  return rb_funcall(#{str_recv}, #{intern_num call_tree[2]}, #{call_args_tree.size-1}, 
                    #{(0..call_args_tree.size-2).map{|i| "arg#{i}"}.join(",")}
                    );
                }
              "
              }
            end
            
            rb_funcall_caller_code_with_lambda = rb_funcall_caller_code
        else
          str_recv = "pframe->next_recv"
          str_recv = "plocals->self" unless recv_tree

            rb_funcall_caller_code = proc { |name| "
              static VALUE #{name}(VALUE param) {
                // call to #{call_tree[2]}
                #{str_lvar_initialization}
                return rb_funcall(#{str_recv}, #{intern_num call_tree[2]}, 0);
              }
            "
            }

            rb_funcall_caller_code_with_lambda = proc { |name| "
              static VALUE #{name}(VALUE param) {
                // call to #{call_tree[2]}
                #{str_lvar_initialization}
              VALUE ret = rb_funcall(#{str_recv}, #{intern_num call_tree[2]}, 0);

              // freeze all stacks
              struct FASTRUBYTHREADDATA* thread_data = rb_current_thread_data();

              if (thread_data != 0) {
                VALUE rb_stack_chunk = thread_data->rb_stack_chunk;

                // add reference to stack chunk to lambda object
                rb_ivar_set(ret,#{intern_num :_fastruby_stack_chunk},rb_stack_chunk);

                // freeze the complete chain of stack chunks
                while (rb_stack_chunk != Qnil) {
                  struct STACKCHUNK* stack_chunk;
                  Data_Get_Struct(rb_stack_chunk,struct STACKCHUNK,stack_chunk);

                  stack_chunk_freeze(stack_chunk);

                  rb_stack_chunk = rb_ivar_get(rb_stack_chunk,#{intern_num :_parent_stack_chunk});
                }
              }

              return ret;
              }
            "
            }

        end
        
        argument_array_read = "
            VALUE arg;
            #{
            # TODO: access directly to argc and argv for optimal execution
            if RUBY_VERSION =~ /^1\.9/ 
              "
                if (TYPE(arg_) == T_ARRAY) {
                  if (_RARRAY_LEN(arg_) <= 1) {
                    arg = rb_ary_new4(argc,argv);
                  } else {
                    arg = arg_;
                  }
                } else {
                  arg = rb_ary_new4(argc,argv);
                }
              "
            else
              "arg = arg_;"
            end
            }
        "
        

        rb_funcall_block_code_with_lambda = proc { |name| "
          static VALUE #{name}(VALUE arg_, VALUE _plocals, int argc, VALUE* argv) {
            // block for call to #{call_tree[2]}
            #{argument_array_read}
            
            VALUE last_expression = Qnil;

            #{@frame_struct} frame;
            #{@frame_struct} *pframe = (void*)&frame;
            #{@locals_struct} *plocals = (void*)_plocals;

            frame.plocals = plocals;
            frame.parent_frame = 0;
            frame.return_value = Qnil;
            frame.rescue = 0;
            frame.targetted = 0;
            frame.thread_data = rb_current_thread_data();

              // create a fake parent frame representing the lambda method frame and a fake locals scope
              VALUE old_call_frame = ((typeof(plocals))(pframe->plocals))->call_frame;
              ((typeof(plocals))(pframe->plocals))->call_frame = LONG2FIX(pframe);

            #{str_arg_initialization}

              int aux = setjmp(frame.jmp);
              if (aux != 0) {
                if (aux == FASTRUBY_TAG_BREAK) {
                  return frame.return_value;
                } else if (aux == FASTRUBY_TAG_NEXT) {
                   return pframe->thread_data->accumulator;
                } else if (aux == FASTRUBY_TAG_REDO) {
                  // do nothing and let execute the block again
                } else if (aux == FASTRUBY_TAG_RAISE) {
                   rb_funcall(((typeof(plocals))(pframe->plocals))->self, #{intern_num :raise}, 1, frame.thread_data->exception);
                   return Qnil;
                } else {
                  if (aux == FASTRUBY_TAG_RETURN) {
                    if (plocals->targetted == 1) {
                      ((typeof(plocals))(pframe->plocals))->call_frame = old_call_frame;
                      return ((typeof(plocals))(pframe->plocals))->return_value;
                    } else {
                      rb_raise(rb_eLocalJumpError, \"unexpected return\");
                    }
                  } else {
                    rb_raise(rb_eLocalJumpError, \"unexpected return\");
                  }

                  ((typeof(plocals))(pframe->plocals))->call_frame = old_call_frame;
                  return frame.return_value;

                }
              }

fastruby_local_redo:
            #{str_impl};

fastruby_local_next:
local_return:
             ((typeof(plocals))(pframe->plocals))->call_frame = old_call_frame;
            return last_expression;
          }
        "
        }

        rb_funcall_block_code_proc_new = proc { |name| "
          static VALUE #{name}(VALUE arg_, VALUE _plocals, int argc, VALUE* argv) {
            // block for call to #{call_tree[2]}
            #{argument_array_read}
            
            VALUE last_expression = Qnil;

            #{@frame_struct} frame;
            #{@frame_struct} *pframe = (void*)&frame;
            #{@locals_struct} *plocals = (void*)_plocals;

            frame.plocals = plocals;
            frame.parent_frame = 0;
            frame.return_value = Qnil;
            frame.rescue = 0;
            frame.targetted = 0;
            frame.thread_data = rb_current_thread_data();

              // create a fake parent frame representing the lambda method frame and a fake locals scope
              VALUE old_call_frame = ((typeof(plocals))(pframe->plocals))->call_frame;
              ((typeof(plocals))(pframe->plocals))->call_frame = LONG2FIX(pframe);

            #{str_arg_initialization}

              int aux = setjmp(frame.jmp);
              if (aux != 0) {
                    if (aux == FASTRUBY_TAG_NEXT) {
                       return pframe->thread_data->accumulator;
                    } else if (aux == FASTRUBY_TAG_REDO) {
                      // do nothing and let execute the block again
                    } else if (aux == FASTRUBY_TAG_RAISE) {
                       rb_funcall(((typeof(plocals))(pframe->plocals))->self, #{intern_num :raise}, 1, frame.thread_data->exception);
                       return Qnil;
                    } else {
_local_return:
                      if (plocals->targetted == 1) {
                        if (plocals->active == Qfalse) {
                          rb_raise(rb_eLocalJumpError,\"return from proc-closure\");
                        } else {
                          ((typeof(plocals))(pframe->plocals))->call_frame = old_call_frame;
                          frb_jump_tag(aux);
                        }
                      } else {
                        rb_raise(rb_eLocalJumpError, \"unexpected return\");
                      }
                    }
              }

fastruby_local_redo:
            #{str_impl};

            ((typeof(plocals))(pframe->plocals))->call_frame = old_call_frame;

            return last_expression;
local_return:
            aux = FASTRUBY_TAG_RETURN;
            plocals->return_value = last_expression;
            plocals->targetted = 1;
            goto _local_return;
fastruby_local_next:
            return last_expression;
          }
        "
        }


        rb_funcall_block_code = proc { |name| "
          static VALUE #{name}(VALUE arg_, VALUE _plocals, int argc, VALUE* argv) {
            // block for call to #{call_tree[2]}
            #{argument_array_read}

            VALUE last_expression = Qnil;

            #{@frame_struct} frame;
            #{@frame_struct} *pframe = (void*)&frame;
            #{@locals_struct} *plocals = (void*)_plocals;

            frame.plocals = plocals;
            frame.parent_frame = 0;
            frame.return_value = Qnil;
            frame.rescue = 0;
            frame.targetted = 0;
            frame.thread_data = rb_current_thread_data();

            #{str_arg_initialization}
            
            int aux = setjmp(frame.jmp);
            if (aux != 0) {

                if (aux == FASTRUBY_TAG_NEXT) {
                  return pframe->thread_data->accumulator;
                } else if (aux == FASTRUBY_TAG_REDO) {
                  // do nothing and let execute the block again
                } else {
                  frb_jump_tag(aux);
                  return frame.return_value;
                }
            }

fastruby_local_redo:
            #{str_impl};

            return last_expression;
local_return:            
            plocals->return_value = last_expression;
            plocals->targetted = 1;
            frb_jump_tag(FASTRUBY_TAG_RETURN);
fastruby_local_next:
            return last_expression;          
            }
        "
        }

        rb_funcall_block_code_callcc = proc { |name| "
          static VALUE #{name}(VALUE arg, VALUE _plocals, int argc, VALUE* argv) {
            #{
            # TODO: access directly to argc and argv for optimal execution
            if RUBY_VERSION =~ /^1\.9/ 
              "arg = rb_ary_new4(argc,argv);"
            end
            }
          
            // block for call to #{call_tree[2]}
            VALUE last_expression = Qnil;

            #{@frame_struct} frame;
            #{@frame_struct} *pframe = (void*)&frame;
            #{@locals_struct} *plocals = (void*)_plocals;

            frame.plocals = plocals;
            frame.parent_frame = 0;
            frame.return_value = Qnil;
            frame.rescue = 0;
            frame.targetted = 0;
            frame.thread_data = rb_current_thread_data();

            #{str_arg_initialization}

            int aux = setjmp(frame.jmp);
            if (aux != 0) {

                if (aux == FASTRUBY_TAG_NEXT) {
                  return pframe->thread_data->accumulator;
                } else if (aux == FASTRUBY_TAG_REDO) {
                  // do nothing and let execute the block again
                } else {
                  frb_jump_tag(aux);
                  return frame.return_value;
                }
            }
            
            if (rb_obj_is_kind_of(arg, rb_const_get(rb_cObject, #{intern_num :Continuation}))) {
              struct FASTRUBYTHREADDATA* thread_data = frame.thread_data;
              rb_ivar_set(arg,#{intern_num :__stack_chunk},thread_data->rb_stack_chunk);
            }

fastruby_local_redo:
            #{str_impl};

            return last_expression;
local_return:            
            plocals->return_value = last_expression;
            plocals->targetted = 1;
            frb_jump_tag(FASTRUBY_TAG_RETURN);
fastruby_local_next:
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
          arguments = args_tree[1][1..-1]
          
          (0..arguments.size-1).each do |i|
            arg = arguments[i]
            if arg[0] == :lasgn 
              fastruby_str_arg_initialization << "plocals->#{arg.last} = #{i} < argc ? argv[#{i}] : Qnil;\n"
            elsif arg[0] == :splat
              fastruby_str_arg_initialization << "plocals->#{arg.last.last} = rb_ary_new2(#{arguments.size-1-i});\n
              {
                int i;
                for (i=#{i};i<argc;i++){
                  rb_ary_store(plocals->#{arg.last.last},i-#{i},argv[i]);
                }
              }
               "
            end 
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
            frame.rescue = 0;
            frame.targetted = 0;
            frame.thread_data = parent_frame->thread_data;
            if (frame.thread_data == 0) frame.thread_data = rb_current_thread_data();

            plocals = frame.plocals;

            #{fastruby_str_arg_initialization}

            int aux = setjmp(frame.jmp);
            if (aux != 0) {
                if (pframe->targetted == 0) {
                  if (aux == FASTRUBY_TAG_NEXT) {
                    return pframe->thread_data->accumulator;
                  } else if (aux == FASTRUBY_TAG_REDO) {
                    // do nothing and let execute the block again
                  } else {
                    longjmp(((typeof(pframe))_parent_frame)->jmp,aux);
                  }
                }

            }

fastruby_local_redo:
            #{str_impl};

            return last_expression;
local_return:
            plocals->return_value = last_expression;
            plocals->targetted = 1;
            longjmp(pframe->jmp, FASTRUBY_TAG_RETURN);
fastruby_local_next:
            return last_expression;          }
        "
        }

        caller_code = nil
        convention_global_name = add_global_name("int",0)
        
          precode = "
              struct FASTRUBYTHREADDATA* thread_data = 0;
              VALUE saved_rb_stack_chunk = Qnil;
              
              VALUE next_recv = plocals->self;
              
              #{
                if recv_tree
                  to_c recv_tree, "next_recv"
                end
              };

              pframe->next_recv = next_recv;
#ifdef RUBY_1_8
              NODE* node = rb_method_node(CLASS_OF(pframe->next_recv), #{intern_num mname});
#endif              
#ifdef RUBY_1_9
              void* node = rb_method_entry(CLASS_OF(pframe->next_recv), #{intern_num mname});
#endif              

              if (node == #{@callcc_node_gvar}) {
                
                // freeze all stacks
                thread_data = rb_current_thread_data();
  
                if (thread_data != 0) {
                  VALUE rb_stack_chunk = thread_data->rb_stack_chunk;
                  saved_rb_stack_chunk = rb_stack_chunk;

                  // freeze the complete chain of stack chunks
                  while (rb_stack_chunk != Qnil) {
                    struct STACKCHUNK* stack_chunk;
                    Data_Get_Struct(rb_stack_chunk,struct STACKCHUNK,stack_chunk);
  
                    stack_chunk_freeze(stack_chunk);
  
                    rb_stack_chunk = rb_ivar_get(rb_stack_chunk,#{intern_num :_parent_stack_chunk});
                  }
                }
              }
            "
          
          postcode = "
              if (node == #{@callcc_node_gvar}) {
                thread_data->rb_stack_chunk = saved_rb_stack_chunk;  
              }
          "              
          
        
          funcall_call_code = "
          #{
            frame_call(
              "ret = " + protected_block("
              
              void* caller_func;
              void* block_func;
              typeof(plocals) current_plocals;
              
              if (pframe->thread_data == 0) pframe->thread_data = rb_current_thread_data();
              void* last_plocals = pframe->thread_data->last_plocals;

#ifdef RUBY_1_8
              NODE* node = rb_method_node(CLASS_OF(pframe->next_recv), #{intern_num mname});
#endif
#ifdef RUBY_1_9
              void* node = rb_method_entry(CLASS_OF(pframe->next_recv), #{intern_num mname});
#endif

              if (
                node == #{@proc_node_gvar} ||
                node == #{@lambda_node_gvar}
                )  {

                caller_func = #{anonymous_function(&rb_funcall_caller_code_with_lambda)};
                block_func = #{anonymous_function(&rb_funcall_block_code_with_lambda)};
              } else if (node == #{@procnew_node_gvar} && pframe->next_recv == rb_cProc) {
                caller_func = #{anonymous_function(&rb_funcall_caller_code_with_lambda)};
                block_func = #{anonymous_function(&rb_funcall_block_code_proc_new)};
              } else if (node == #{@callcc_node_gvar}) {
                caller_func = #{anonymous_function(&rb_funcall_caller_code)};
                block_func = #{anonymous_function(&rb_funcall_block_code_callcc)};
              } else {
                caller_func = #{anonymous_function(&rb_funcall_caller_code)};
                block_func = #{anonymous_function(&rb_funcall_block_code)};
              }
              

              last_expression = rb_iterate(
                caller_func,
                (VALUE)pframe,
                block_func,
                (VALUE)plocals);

              if (node == #{@callcc_node_gvar}) {
  
                // remove active flags of abandoned stack
                current_plocals = pframe->thread_data->last_plocals;
                while (current_plocals) {
                  current_plocals->active = Qfalse;
                  current_plocals = (typeof(current_plocals))FIX2LONG(current_plocals->parent_locals); 
                }
                
                // restore last_plocals
                pframe->thread_data->last_plocals = last_plocals;
                
                // mark all scopes as active
                current_plocals = last_plocals;
                
                while (current_plocals) {
                  current_plocals->active = Qtrue;
                  current_plocals = (typeof(current_plocals))FIX2LONG(current_plocals->parent_locals); 
                }
              }
              ", true), precode, postcode
            )
          };
          "        

      recvtype = nil if call_args_tree.size > 1 ? call_args_tree.last[0] == :splat : false
      unless recvtype
        if result_var
          "#{result_var} = #{funcall_call_code};"
        else
          funcall_call_code
        end
      else
        encoded_address = encode_address(recvtype,signature,mname,call_tree,inference_complete,convention_global_name)

        if call_args_tree.size > 1
          value_cast = ( ["VALUE"]*(call_tree[3].size) ).join(",") + ", VALUE, VALUE"
          strargs = "," + (0..call_args_tree.size-2).map{|i| "arg#{i}"}.join(",")
        else
          value_cast = "VALUE,VALUE,VALUE"
          strargs = ""
        end

        fastruby_call_code = "
                // call to #{call_tree[2]}
                #{
                if call_args_tree.size > 1
                  str_evaluate_args
                end
                };
                
                VALUE recv = plocals->self;
                
                #{
                if recv_tree
                 to_c recv_tree, "recv" 
                end
                } 

                ret = ((VALUE(*)(#{value_cast}))#{encoded_address})(recv, (VALUE)&block, (VALUE)&call_frame #{strargs});
            "
        
        code = "
          if (#{@last_address_name} == 0) {
            return #{funcall_call_code};
          } else {
            #{if recvtype and inference_complete
              "if (*#{@last_address_name} == 0) {
                rb_funcall(#{literal_value recvtype},#{intern_num :build}, 2, #{literal_value signature}, #{literal_value mname});
              }
              "
            end
            }
            if (*#{@last_address_name} == 0) {
              return #{funcall_call_code};
            } else {
              #{fastruby_call_code}
            }
          }
        "
        
        fastruby_precode = "                 #{@block_struct} block;

                block.block_function_address = (void*)#{anonymous_function(&block_code)};
                block.block_function_param = (void*)plocals;
                "
        
        if result_var
          "#{result_var} = #{frame_call(code,fastruby_precode,"")}"
        else
          frame_call(code,fastruby_precode,"")
        end
        
      end
    end
  end
end
