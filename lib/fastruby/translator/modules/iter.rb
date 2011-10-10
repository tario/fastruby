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

              if anonymous_impl[-1][0] != :return and anonymous_impl[-1][0] != :break and anonymous_impl[-1][0] != :next
                str_impl = str_impl + ";last_expression = (#{to_c(anonymous_impl[-1])});"
              else
                str_impl = str_impl + ";#{to_c(anonymous_impl[-1])};"
              end
            else
              if anonymous_impl[0] != :return and anonymous_impl[0] != :break and anonymous_impl[0] != :next
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

          str_recv = "pframe->next_recv"

          str_recv = "plocals->self" unless recv_tree
            if call_args_tree.last[0] == :splat
              rb_funcall_caller_code = proc { |name| "
                static VALUE #{name}(VALUE param) {
                  // call to #{call_tree[2]}
  
                  #{str_lvar_initialization}
                  
                  VALUE array = #{to_c call_args_tree.last[1]};
                  
                  if (TYPE(array) != T_ARRAY) {
                    array = rb_ary_new4(1,&array);
                  }
                  
                  int argc = #{call_args_tree.size-2};
                  VALUE argv[#{call_args_tree.size} + RARRAY(array)->len];
                  
                  #{
                    i = -1
                    call_args_tree[1..-2].map {|arg|
                      i = i + 1
                      "argv[#{i}] = #{to_c arg}"
                    }.join(";\n")
                  };
                  
                  int array_len = RARRAY(array)->len;
                  
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
              str_called_code_args = call_args_tree[1..-1].map{ |subtree| to_c subtree }.join(",")
              rb_funcall_caller_code = proc { |name| "
                static VALUE #{name}(VALUE param) {
                  // call to #{call_tree[2]}
  
                  #{str_lvar_initialization}
                  return rb_funcall(#{str_recv}, #{intern_num call_tree[2]}, #{call_args_tree.size-1}, #{str_called_code_args});
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

        rb_funcall_block_code_with_lambda = proc { |name| "
          static VALUE #{name}(VALUE arg, VALUE _plocals) {
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

              // create a fake parent frame representing the lambda method frame and a fake locals scope
              VALUE old_call_frame = ((typeof(plocals))(pframe->plocals))->call_frame;
              ((typeof(plocals))(pframe->plocals))->call_frame = LONG2FIX(pframe);

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

            #{str_arg_initialization}
            #{str_impl}

             ((typeof(plocals))(pframe->plocals))->call_frame = old_call_frame;
            return last_expression;
          }
        "
        }

        rb_funcall_block_code_proc_new = proc { |name| "
          static VALUE #{name}(VALUE arg, VALUE _plocals) {
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

              // create a fake parent frame representing the lambda method frame and a fake locals scope
              VALUE old_call_frame = ((typeof(plocals))(pframe->plocals))->call_frame;
              ((typeof(plocals))(pframe->plocals))->call_frame = LONG2FIX(pframe);

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
                      if (plocals->targetted == 1) {
                        if (plocals->active == Qfalse) {
                          rb_raise(rb_eLocalJumpError,\"return from proc-closure\");
                        } else {
                          ((typeof(plocals))(pframe->plocals))->call_frame = old_call_frame;
                          rb_jump_tag(aux);
                        }
                      } else {
                        rb_raise(rb_eLocalJumpError, \"unexpected return\");
                      }
                    }
              }

            #{str_arg_initialization}
            #{str_impl}

            ((typeof(plocals))(pframe->plocals))->call_frame = old_call_frame;

            return last_expression;
          }
        "
        }


        rb_funcall_block_code = proc { |name| "
          static VALUE #{name}(VALUE arg, VALUE _plocals) {
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

            int aux = setjmp(frame.jmp);
            if (aux != 0) {

                if (aux == FASTRUBY_TAG_NEXT) {
                  return pframe->thread_data->accumulator;
                } else if (aux == FASTRUBY_TAG_REDO) {
                  // do nothing and let execute the block again
                } else {
                  rb_jump_tag(aux);
                  return frame.return_value;
                }
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
            frame.return_value = Qnil;
            frame.rescue = 0;
            frame.targetted = 0;
            frame.thread_data = parent_frame->thread_data;
            if (frame.thread_data == 0) frame.thread_data = rb_current_thread_data();

            plocals = frame.plocals;

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

        call_frame_struct_code = "
                #{@block_struct} block;
                #{@locals_struct} *plocals = (void*)param;

                block.block_function_address = (void*)#{anonymous_function(&block_code)};
                block.block_function_param = (void*)param;

                // create a call_frame
                #{@frame_struct} call_frame;

                call_frame.parent_frame = (void*)pframe;
                call_frame.plocals = plocals;
                call_frame.return_value = Qnil;
                call_frame.targetted = 0;
                call_frame.thread_data = rb_current_thread_data();

                VALUE old_call_frame = plocals->call_frame;
                plocals->call_frame = LONG2FIX(&call_frame);

                int aux = setjmp(call_frame.jmp);
                if (aux != 0) {
                  #{@frame_struct}* pframe_ = (void*)pframe;

                  if (aux == FASTRUBY_TAG_RETRY ) {
                    // do nothing and let the call execute again
                  } else {
                    if (call_frame.targetted == 0) {
                      longjmp(pframe_->jmp,aux);
                    }

                    plocals->call_frame = old_call_frame;
                    return call_frame.return_value;
                  }
                }
        "
        
          funcall_call_code = "
          return #{
            frame_call(
              protected_block(inline_block("

              pframe->next_recv = #{recv_tree ? to_c(recv_tree) : "plocals->self"};

              NODE* node = rb_method_node(CLASS_OF(pframe->next_recv), #{intern_num mname});
              void* caller_func;
              void* block_func;

              if (
                node == #{@proc_node_gvar} ||
                node == #{@lambda_node_gvar}
                )  {

                caller_func = #{anonymous_function(&rb_funcall_caller_code_with_lambda)};
                block_func = #{anonymous_function(&rb_funcall_block_code_with_lambda)};
              } else if (node == #{@procnew_node_gvar} && pframe->next_recv == rb_cProc) {
                caller_func = #{anonymous_function(&rb_funcall_caller_code_with_lambda)};
                block_func = #{anonymous_function(&rb_funcall_block_code_proc_new)};
              } else {
                caller_func = #{anonymous_function(&rb_funcall_caller_code)};
                block_func = #{anonymous_function(&rb_funcall_block_code)};
              }

              return rb_iterate(
                caller_func,
                (VALUE)pframe,
                block_func,
                (VALUE)plocals);

              "), true)
            )
          };
          "        

      if call_args_tree.size > 1 ? call_args_tree.last[0] == :splat : false
        inline_block "
          #{funcall_call_code}
        "
      else

        if call_args_tree.size > 1
          value_cast = ( ["VALUE"]*(call_tree[3].size) ).join(",") + ", VALUE, VALUE"

          str_called_code_args = call_tree[3][1..-1].map{|subtree| to_c subtree}.join(",")

            caller_code = proc { |name| "
              static VALUE #{name}(VALUE param, VALUE pframe) {
                // call to #{call_tree[2]}
                #{call_frame_struct_code}

                VALUE ret = ((VALUE(*)(#{value_cast}))#{encode_address(recvtype,signature,mname,call_tree,inference_complete,convention_global_name)})(#{str_recv}, (VALUE)&block, (VALUE)&call_frame, #{str_called_code_args});
                plocals->call_frame = old_call_frame;
                return ret;
              }
            "
            }

        else
            caller_code = proc { |name| "
              static VALUE #{name}(VALUE param, VALUE pframe) {
                #{call_frame_struct_code}

                // call to #{call_tree[2]}
                VALUE ret = ((VALUE(*)(VALUE,VALUE,VALUE))#{encode_address(recvtype,signature,mname,call_tree,inference_complete,convention_global_name)})(#{str_recv}, (VALUE)&block, (VALUE)&call_frame);
                plocals->call_frame = old_call_frame;
                return ret;
              }
            "
            }
        end
        
        inline_block "
          if (#{convention_global_name}) {
            return #{anonymous_function(&caller_code)}((VALUE)plocals, (VALUE)pframe);
          } else {
            #{funcall_call_code}
          }
        "
      end
    end
  end
end