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
  module CallTranslator
    
    register_translator_module self

    def to_c_call(tree, result_var = nil)
      directive_code = directive(tree)
      repass_var = @repass_var

      if directive_code
        if result_var
          return "#{result_var} = #{directive_code};\n"
        else
          return directive_code
        end
      end
      
      if tree[2] == :require
        tree[2] = :fastruby_require
      elsif tree[2] == :raise
        # raise code
        args = tree[3]
        return _raise(args[1],args[2])
      end

      recv = tree[1]
      mname = tree[2]
      args = tree[3]
      args_tree = tree[3]
      
      # search block_pass on arguments
      block_pass_arg = args.find{|arg| if arg == :arglist
            false
          else
          arg[0] == :block_pass
            end} 

      if block_pass_arg
        args_tree = args_tree.dup.reject{|st| 
          if st.respond_to? :node_type
            st.node_type == :block_pass
          else 
            false
          end
         }
        args = args_tree
      end
 
      mname = :require_fastruby if mname == :require

      argnum = args.size - 1

      recv = recv || s(:self)

      recvtype = infer_type(recv)
      
      if args.size > 1
        if args.last[0] == :splat

          if block_pass_arg
            
            call_tree = tree.dup
            call_tree[3] = args.select{|arg| if arg == :arglist 
                true
                else
                  arg[0] != :block_pass
                  end
                  }
            
            block_arguments_tree = s(:masgn, s(:array, s(:splat, s(:lasgn, :__xblock_arguments))))
            block_tree = s(:call, s(:lvar, :__x_proc), :call, s(:arglist, s(:splat, s(:lvar, :__xblock_arguments))))
            
            replace_iter_tree = s(:block,
                s(:lasgn, :__x_proc, s(:call, block_pass_arg[1], :to_proc, s(:arglist))),
                s(:iter, call_tree, block_arguments_tree, block_tree)
                ).to_fastruby_sexp
          
            if result_var  
              return to_c(replace_iter_tree,result_var)
            else
              return to_c(replace_iter_tree)
            end
          end

          aux_varname = "_aux_" + rand(1000000).to_s
          code = protected_block(
            "
            
            VALUE array = Qnil;
            
            #{to_c args.last[1], "array"};
            
            if (TYPE(array) != T_ARRAY) {
              array = rb_ary_new4(1,&array);
            }
            
            int argc = #{args.size-2};
            VALUE argv[#{args.size} + _RARRAY_LEN(array)];
            VALUE #{aux_varname} = Qnil;
            #{
              i = -1
              args[1..-2].map {|arg|
                i = i + 1
                "#{to_c arg, aux_varname};
                argv[#{i}] = #{aux_varname};
                "
              }.join(";\n")
            };
            
            VALUE recv = Qnil;
            
            #{to_c recv, "recv"};
            
            int array_len = _RARRAY_LEN(array);
            
            int i;
            for (i=0; i<array_len;i++) {
              argv[argc] = rb_ary_entry(array,i);
              argc++; 
            }
            
            last_expression = rb_funcall2(recv, #{intern_num tree[2]}, argc, argv);
            ", true, repass_var)
            
          if result_var
           return "#{result_var} = #{code};\n"
          else
           return code
          end
        end
      end

      if recvtype

        address = nil
        mobject = nil

        inference_complete = true
        signature = [recvtype]

        args[1..-1].each do |arg|
          argtype = infer_type(arg)
          signature << argtype
          unless argtype
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

          block_proc_tree = s(:call, block_pass_arg[1], :to_proc, s(:arglist)) if block_pass_arg

          block_wrapping_proc = proc { |name| "
            static VALUE #{name}(int argc, VALUE* argv, VALUE _locals, VALUE _parent_frame) {
              return rb_proc_call(_locals, rb_ary_new4(argc, argv)); 
            }
          "
          }
 
          if argnum == 0
            value_cast = "VALUE,VALUE,VALUE"


              if block_pass_arg or result_var
                code = "
                {
                VALUE recv = Qnil;
                #{to_c recv, "recv"};

                #{@block_struct} block, *pblock = Qfalse;

                #{if block_pass_arg
                "
                VALUE proc = Qnil;
                #{to_c(block_proc_tree, "proc") }

                VALUE block_address_value = rb_ivar_get(proc, #{intern_num "__block_address"});

                if (block_address_value != Qnil) {
                  block.block_function_address = block_address_value;
                  block.block_function_param = rb_ivar_get(proc, #{intern_num "__block_param"});
                  block.proc = proc;
                  pblock = &block;
                } else {
                  // create a block from a proc
                  block.block_function_address = ((void*)#{anonymous_function(&block_wrapping_proc)});
                  block.block_function_param = proc;
                  block.proc = proc;
                  pblock = &block;
                }

                "
                end
                }

                #{if result_var
                "
                #{result_var} = ((VALUE(*)(#{value_cast}))#{encode_address(recvtype,signature,mname,tree,inference_complete)})(recv, (VALUE)pblock, (VALUE)pframe);
                "
                else
                "
                ((VALUE(*)(#{value_cast}))#{encode_address(recvtype,signature,mname,tree,inference_complete)})(recv, (VALUE)pblock, (VALUE)pframe);
                "
                end
                }
                }
                "
              
                result_var ? code : inline_block(code)
              else
                 "((VALUE(*)(#{value_cast}))#{encode_address(recvtype,signature,mname,tree,inference_complete)})(#{to_c recv}, Qfalse, (VALUE)pframe)"               
              end          

          else
            value_cast = ( ["VALUE"]*(args.size) ).join(",") + ",VALUE,VALUE"
            suffix = "_" + rand(1000000).to_s+"_"

                strargs = (0..args_tree.size-2).map{|i| "#{suffix}arg#{i}"}.join(",")
              if block_pass_arg or result_var
                code = "
                {
                VALUE recv = Qnil;
                
                #{
                (0..args_tree.size-2).map{ |x|
                  "VALUE #{suffix}arg#{x};"
                }.join("\n")
                }

                #{
                (0..args_tree.size-2).map{ |x|
                  to_c(args_tree[x+1], "#{suffix}arg#{x}") + ";"
                }.join("\n")
                }
                
                #{to_c recv, "recv"};

                #{@block_struct} block, *pblock = Qfalse;

                #{if block_pass_arg
                "
                VALUE proc = Qnil;
                #{to_c(block_proc_tree, "proc") }
                VALUE block_address_value = rb_ivar_get(proc, #{intern_num "__block_address"});
                if (block_address_value != Qnil) {
                  block.block_function_address = block_address_value;
                  block.block_function_param = (rb_ivar_get(proc, #{intern_num "__block_param"}));
                  block.proc = proc;
                  pblock = &block;
                } else {
                  // create a block from a proc
                  block.block_function_address = ((void*)#{anonymous_function(&block_wrapping_proc)});
                  block.block_function_param = proc;
                  block.proc = proc;
                  pblock = &block;
                }

                "
                end
                }

                #{if result_var
                "
                #{result_var} = ((VALUE(*)(#{value_cast}))#{encode_address(recvtype,signature,mname,tree,inference_complete)})(recv, (VALUE)pblock, (VALUE)pframe, #{strargs});
                "
                else
                "
                ((VALUE(*)(#{value_cast}))#{encode_address(recvtype,signature,mname,tree,inference_complete)})(recv, (VALUE)pblock, (VALUE)pframe, #{strargs});
                "
                end
                }

                
                }
                "
                result_var ? code : inline_block(code)
              else
                strargs = args[1..-1].map{|arg| to_c arg}.join(",")
                "((VALUE(*)(#{value_cast}))#{encode_address(recvtype,signature,mname,tree,inference_complete)})(#{to_c recv}, Qfalse, (VALUE)pframe, #{strargs})"
              end
          end

      else # else recvtype
        if argnum == 0
          code = protected_block("last_expression = rb_funcall(#{to_c recv}, #{intern_num tree[2]}, 0)", true, repass_var)
          if result_var
          "
            #{result_var} = #{code};
          "
          else
            code
          end
        else
          strargs = args[1..-1].map{|arg| to_c arg}.join(",")
          code = protected_block("last_expression = rb_funcall(#{to_c recv}, #{intern_num tree[2]}, #{argnum}, #{strargs} )", true, repass_var)
          if result_var
          "
            #{result_var} = #{code};
          "
          else
            code
          end
        end
      end # if recvtype
    end

    def to_c_attrasgn(tree)
      to_c_call(tree)
    end
  end
end
