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
require "rubygems"
require "sexp"
require "fastruby/method_extension"
require "fastruby/set_tree"
require "fastruby/exceptions"
require "fastruby/translator/translator_modules"


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
    
    TranslatorModules.instance.load_under(FastRuby.fastruby_load_path + "/fastruby/translator/modules/")
    TranslatorModules.instance.modls.each do |modl|
      include modl
    end

    def initialize(common_func = true)
      @infer_lvar_map = Hash.new
      @no_cache = false
      @extra_code = ""
      @options = {}
      @init_extra = Array.new
      @frame_struct = "struct {
        void* parent_frame;
        void* plocals;
        jmp_buf jmp;
        VALUE return_value;
        int rescue;
        VALUE last_error;
        VALUE next_recv;
        int targetted;
        struct FASTRUBYTHREADDATA* thread_data;
      }"

      @block_struct = "struct {
        void* block_function_address;
        void* block_function_param;
      }"


      extra_code << "
        #include \"node.h\"

        #define FASTRUBY_TAG_RETURN 0x80
        #define FASTRUBY_TAG_NEXT 0x81
        #define FASTRUBY_TAG_BREAK 0x82
        #define FASTRUBY_TAG_RAISE 0x83
        #define FASTRUBY_TAG_REDO 0x84
        #define FASTRUBY_TAG_RETRY 0x85
        #define TAG_RAISE 0x6

        #ifndef __INLINE_FASTRUBY_BASE
        #include \"#{FastRuby.fastruby_load_path}/../ext/fastruby_base/fastruby_base.inl\"
        #define __INLINE_FASTRUBY_BASE
        #endif
      "

      ruby_code = "
        $LOAD_PATH << #{FastRuby.fastruby_load_path.inspect}
        require #{FastRuby.fastruby_script_path.inspect}
      "

      init_extra << "
        rb_eval_string(#{ruby_code.inspect});
    	"

      @lambda_node_gvar = add_global_name("NODE*", 0);
      @proc_node_gvar = add_global_name("NODE*", 0);
      @procnew_node_gvar = add_global_name("NODE*", 0);

      init_extra << "
        #{@lambda_node_gvar} = rb_method_node(rb_cObject, #{intern_num :lambda});
        #{@proc_node_gvar} = rb_method_node(rb_cObject, #{intern_num :proc});
        #{@procnew_node_gvar} = rb_method_node(CLASS_OF(rb_cProc), #{intern_num :new});
      "

      @common_func = common_func
      if common_func
        extra_code << "static VALUE _rb_gvar_set(void* ge,VALUE value) {
          rb_gvar_set((struct global_entry*)ge,value);
          return value;
        }
        "

        extra_code << "static VALUE re_yield(int argc, VALUE* argv, VALUE param, VALUE _parent_frame) {
         VALUE yield_args = rb_ary_new4(argc,argv);
         VALUE* yield_args_p = &yield_args;

         #{@frame_struct}* pframe;
         pframe = (typeof(pframe))_parent_frame;

         return #{protected_block("rb_yield_splat(*(VALUE*)yield_args_p)",true,"yield_args_p",true)};
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

    def to_c(tree)
      return "Qnil" unless tree
      send("to_c_" + tree[0].to_s, tree);
    end

    def anonymous_function

      name = "anonymous" + rand(10000000).to_s
      extra_code << yield(name)

      name
    end

    def frame_call(inner_code)
      inline_block "


        // create a call_frame
        #{@frame_struct} call_frame;
        typeof(call_frame)* old_pframe = (void*)pframe;

        pframe = (typeof(pframe))&call_frame;

        call_frame.parent_frame = (void*)pframe;
        call_frame.plocals = plocals;
        call_frame.return_value = Qnil;
        call_frame.targetted = 0;
        call_frame.thread_data = old_pframe->thread_data;
        if (call_frame.thread_data == 0) call_frame.thread_data = rb_current_thread_data();

        VALUE old_call_frame = plocals->call_frame;
        plocals->call_frame = LONG2FIX(&call_frame);

                int aux = setjmp(call_frame.jmp);
                if (aux != 0) {
                  if (call_frame.targetted == 0) {
                    longjmp(old_pframe->jmp,aux);
                  }

                  if (aux == FASTRUBY_TAG_BREAK) {
                    plocals->call_frame = old_call_frame;
                    return call_frame.return_value;
                  } else if (aux == FASTRUBY_TAG_RETRY ) {
                    // do nothing and let the call execute again
                  } else {
                    plocals->call_frame = old_call_frame;
                    return call_frame.return_value;
                  }
                }

        VALUE ret = #{inner_code};
        plocals->call_frame = old_call_frame;
        return ret;
      "
    end

    def initialize_method_structs(args_tree)
      @locals_struct = "struct {
        VALUE return_value;
        VALUE pframe;
        VALUE block_function_address;
        VALUE block_function_param;
        VALUE call_frame;
        VALUE active;
        VALUE targetted;
        #{@locals.map{|l| "VALUE #{l};\n"}.join}
        }"

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

          ID id = rb_intern(RSTRING(method_name)->ptr);
          
          rb_funcall(
                #{literal_value FastRuby},
                #{intern_num :set_builder_module},
                1,
                #{literal_value klass}
                );
          
          VALUE rb_method_hash;
          void** address = 0;
          rb_method_hash = rb_funcall(#{literal_value klass}, #{intern_num :method_hash},1,#{literal_value method_name});

          if (rb_method_hash != Qnil) {
            VALUE tmp = rb_hash_aref(rb_method_hash, LONG2FIX(id));
            if (tmp != Qnil) {
                address = (void*)FIX2LONG(tmp);
            }
          }
          
          if (address == 0) {
            address = malloc(sizeof(void*));
          }
          *address = #{alt_method_name};
          
          rb_funcall(
              #{literal_value klass},
              #{intern_num :register_method_value}, 
              3,
              #{literal_value method_name},
              LONG2FIX(id),
              LONG2FIX(address)
              );
        }
      "
    end

    def to_c_method(tree, signature = nil)
      
      if tree[0] == :defn
        method_name = tree[1]
        original_args_tree = tree[2]
        block_argument = tree[2].find{|x| x.to_s[0] == ?&}
        impl_tree = tree[3][1]
      elsif tree[0] == :defs
        method_name = tree[2]
        original_args_tree = tree[3]
        block_argument = tree[3].find{|x| x.to_s[0] == ?&}
        impl_tree = tree[4][1]
      end

      args_tree = original_args_tree.select{|x| x.to_s[0] != ?&}

      if (options[:main])
        initialize_method_structs(original_args_tree)

        strargs = if args_tree.size > 1
          "VALUE block, VALUE _parent_frame, #{(0..signature.size-1).map{|x| "VALUE arg#{x}"}.join(",")}"
        else
          "VALUE block, VALUE _parent_frame"
        end

        ret = "VALUE #{@alt_method_name || method_name}() {

          #{@locals_struct} *plocals;
          #{@frame_struct} frame;
          #{@frame_struct} *pframe;

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
          plocals->active = Qtrue;
          plocals->targetted = Qfalse;
          plocals->pframe = LONG2FIX(&frame);
          frame.plocals = plocals;

          pframe = (void*)&frame;

          VALUE last_expression = Qnil;

          int aux = setjmp(pframe->jmp);
          if (aux != 0) {
            stack_chunk_set_current_position(stack_chunk, previous_stack_position);

            if (stack_chunk_instantiated) {
              rb_gc_unregister_address(&rb_stack_chunk);
              frame.thread_data->rb_stack_chunk = rb_previous_stack_chunk;
            }

            plocals->active = Qfalse;
            return plocals->return_value;
          }

          plocals->self = self;

          #{args_tree[1..-1].map { |arg|
            arg = arg.to_s
            arg.gsub!("*","")
            "plocals->#{arg} = #{arg};\n"
          }.join("") }

          plocals->block_function_address = LONG2FIX(0);
          plocals->block_function_param = LONG2FIX(Qnil);
          plocals->call_frame = LONG2FIX(0);

          VALUE ret = #{to_c impl_tree};
          stack_chunk_set_current_position(stack_chunk, previous_stack_position);

          if (stack_chunk_instantiated) {
            rb_gc_unregister_address(&rb_stack_chunk);
            frame.thread_data->rb_stack_chunk = rb_previous_stack_chunk;
          }

          plocals->active = Qfalse;
          return ret;

        }"

        add_main
        ret
      else

        initialize_method_structs(original_args_tree)
        
        strargs = if args_tree.size > 1
          "VALUE block, VALUE _parent_frame, #{(0..signature.size-1).map{|x| "VALUE arg#{x}"}.join(",")}"
        else
          "VALUE block, VALUE _parent_frame"
        end
        
        splat_arg = args_tree[1..-1].find{|x| x.to_s.match(/\*/) }

        maxargnum = args_tree[1..-1].count{ |x|
            if x.instance_of? Symbol
              not x.to_s.match(/\*/) and not x.to_s.match(/\&/)
            else
              false
            end
          }
          
        minargnum = maxargnum
          
        args_tree[1..-1].each do |subtree|
          unless subtree.instance_of? Symbol
            if subtree[0] == :block
              minargnum = minargnum - (subtree.size-1)
            end
          end
        end
        
        if args_tree[1..-1].find{|x| x.to_s.match(/\*/)}
          maxargnum = 2147483647
        end
        
        read_arguments_code = ""


        validate_arguments_code = if signature.size-1 < minargnum
            "
              rb_raise(rb_eArgError, \"wrong number of arguments (#{signature.size-1} for #{minargnum})\");
            "
        elsif signature.size-1 > maxargnum
            "
              rb_raise(rb_eArgError, \"wrong number of arguments (#{signature.size-1} for #{maxargnum})\");
            "
        else

            default_block_tree = args_tree[1..-1].find{|subtree|
              unless subtree.instance_of? Symbol
                if subtree[0] == :block
                  next true
                end
              end
    
              false
            }
            
            i = -1

            normalargsnum = args_tree[1..-1].count{|subtree|
              if subtree.instance_of? Symbol
                unless subtree.to_s.match(/\*/)
                  next true
                end
              end
                    
              false
            }

            read_arguments_code = args_tree[1..-1].map { |arg_|
                arg = arg_.to_s
                i = i + 1
    
                if i < normalargsnum
                  if i < signature.size-1
                    "plocals->#{arg} = arg#{i};\n"
                  else
                      
                    if default_block_tree
                      initialize_tree = default_block_tree[1..-1].find{|subtree| subtree[1] == arg_}
                      if initialize_tree
                        to_c(initialize_tree) + ";\n"
                      else
                        ""
                      end
                    else
                        ";\n"
                    end
                  end
                else
                  ""
                end
              }.join("")
              
            if splat_arg
                  if signature.size-1 < normalargsnum then
                    read_arguments_code << "
                      plocals->#{splat_arg.to_s.gsub("*","")} = rb_ary_new3(0);
                      "
                  else
                      arguments_array = [(signature.size-1) - (normalargsnum)] + (normalargsnum..signature.size-1).map{|x| "arg#{x}"}
                      
                    read_arguments_code << "
                      plocals->#{splat_arg.to_s.gsub("*","")} = rb_ary_new3(
                            #{arguments_array.join(",")} 
                            );
                    "
                  end
    
            end
          
          
            ""
        end

        if block_argument

          proc_reyield_block_tree = s(:iter, s(:call, nil, :proc, s(:arglist)), s(:masgn, s(:array, s(:splat, s(:lasgn, :__xproc_arguments)))), s(:yield, s(:splat, s(:lvar, :__xproc_arguments))))

          read_arguments_code << "
            plocals->#{block_argument.to_s.gsub("&","")} = #{to_c proc_reyield_block_tree.to_fastruby_sexp};
          "
        end

        ret = "VALUE #{@alt_method_name || method_name}(#{strargs}) {
          #{validate_arguments_code}

          #{@frame_struct} frame;
          #{@frame_struct} *pframe;
          
          frame.parent_frame = (void*)_parent_frame;
          frame.return_value = Qnil;
          frame.rescue = 0;
          frame.targetted = 0;
          frame.thread_data = ((typeof(pframe))_parent_frame)->thread_data;
          if (frame.thread_data == 0) frame.thread_data = rb_current_thread_data();

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


          #{@locals_struct} *plocals;

          int previous_stack_position = stack_chunk_get_current_position(stack_chunk);

          plocals = (typeof(plocals))stack_chunk_alloc(stack_chunk ,sizeof(typeof(*plocals))/sizeof(void*));
          frame.plocals = plocals;
          plocals->active = Qtrue;
          plocals->targetted = Qfalse;
          plocals->pframe = LONG2FIX(&frame);
          plocals->call_frame = LONG2FIX(0);

          pframe = (void*)&frame;

          #{@block_struct} *pblock;
          VALUE last_expression = Qnil;

          int aux = setjmp(pframe->jmp);
          if (aux != 0) {
            plocals->active = Qfalse;

            stack_chunk_set_current_position(stack_chunk, previous_stack_position);

            if (stack_chunk_instantiated) {
              rb_gc_unregister_address(&rb_stack_chunk);
              frame.thread_data->rb_stack_chunk = rb_previous_stack_chunk;
            }

            if (plocals->targetted == Qfalse) {
              longjmp(((typeof(pframe))_parent_frame)->jmp,aux);
            }

            return plocals->return_value;
          }

          plocals->self = self;

          #{read_arguments_code}

          pblock = (void*)block;
          if (pblock) {
            plocals->block_function_address = LONG2FIX(pblock->block_function_address);
            plocals->block_function_param = LONG2FIX(pblock->block_function_param);
          } else {
            plocals->block_function_address = LONG2FIX(0);
            plocals->block_function_param = LONG2FIX(Qnil);
          }

          VALUE __ret = #{to_c impl_tree};
          stack_chunk_set_current_position(stack_chunk, previous_stack_position);

          if (stack_chunk_instantiated) {
            rb_gc_unregister_address(&rb_stack_chunk);
            frame.thread_data->rb_stack_chunk = rb_previous_stack_chunk;
          }

          plocals->active = Qfalse;
          return __ret;
        }"

        add_main
        ret
      end
    end

    def locals_accessor
      "plocals->"
    end

    def locals_scope(locals)
       old_locals = @locals
       old_locals_struct = @locals_struct

       @locals = locals
        @locals_struct = "struct {
        VALUE return_value;
        VALUE pframe;
        VALUE block_function_address;
        VALUE block_function_param;
        VALUE call_frame;
        VALUE active;
        VALUE targetted;
        #{@locals.map{|l| "VALUE #{l};\n"}.join}
        }"

      begin
        yield
      ensure
        @locals = old_locals
        @locals_struct = old_locals_struct
      end
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
        return "FIX2LONG(plocals->block_function_address) == 0 ? Qfalse : Qtrue"
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

    def inline_block_reference(arg, nolocals = false)
      code = nil

      if arg.instance_of? FastRuby::FastRubySexp
        code = to_c(arg);
      else
        code = arg
      end

      anonymous_function{ |name| "
        static VALUE #{name}(VALUE param) {
          #{@frame_struct} *pframe = (void*)param;

          #{nolocals ? "" : "#{@locals_struct} *plocals = (void*)pframe->plocals;"}
          VALUE last_expression = Qnil;

          #{code};
          return last_expression;
          }
        "
      }
    end

    def inline_block(code, repass_var = nil, nolocals = false)
      anonymous_function{ |name| "
        static VALUE #{name}(VALUE param#{repass_var ? ",void* " + repass_var : "" }) {
          #{@frame_struct} *pframe = (void*)param;

          #{nolocals ? "" : "#{@locals_struct} *plocals = (void*)pframe->plocals;"}
          VALUE last_expression = Qnil;

          #{code}
          }
        "
      } + "((VALUE)pframe#{repass_var ? ", " + repass_var : "" })"
    end

    def inline_ruby(proced, parameter)
      "rb_funcall(#{proced.__id__}, #{intern_num :call}, 1, #{parameter})"
    end

    def protected_block(inner_code, always_rescue = false,repass_var = nil, nolocals = false)
      body = nil
      rescue_args = nil
      if repass_var
        body =  anonymous_function{ |name| "
          static VALUE #{name}(VALUE param) {

            #{@frame_struct} frame;

            typeof(frame)* pframe;
            typeof(frame)* parent_frame = ((typeof(pframe))((void**)param)[0]);

            frame.parent_frame = 0;
            frame.return_value = Qnil;
            frame.rescue = 0;
            frame.last_error = Qnil;
            frame.targetted = 0;
            frame.thread_data = parent_frame->thread_data;
            if (frame.thread_data == 0) frame.thread_data = rb_current_thread_data();

            pframe = &frame;

            #{
            nolocals ? "frame.plocals = 0;" : "#{@locals_struct}* plocals = parent_frame->plocals;
            frame.plocals = plocals;
            "
            }

            int aux = setjmp(frame.jmp);
            if (aux != 0) {

              if (frame.targetted == 1) {
                return frame.return_value;
              } else {
                rb_jump_tag(aux);
              }
            }

            VALUE #{repass_var} = (VALUE)((void**)param)[1];
            return #{inner_code};
            }
          "
        }

        rescue_args = ""
        rescue_args = "(VALUE)(VALUE[]){(VALUE)pframe,(VALUE)#{repass_var}}"
      else

        body = anonymous_function{ |name| "
          static VALUE #{name}(VALUE param) {
            #{@frame_struct} frame;

            typeof(frame)* pframe;
            typeof(frame)* parent_frame = (typeof(pframe))param;

            frame.parent_frame = 0;
            frame.return_value = Qnil;
            frame.rescue = 0;
            frame.last_error = Qnil;
            frame.targetted = 0;
            frame.thread_data = parent_frame->thread_data;
            if (frame.thread_data == 0) frame.thread_data = rb_current_thread_data();

            pframe = &frame;

            #{
            nolocals ? "frame.plocals = 0;" : "#{@locals_struct}* plocals = parent_frame->plocals;
            frame.plocals = plocals;
            "
            }

            int aux = setjmp(frame.jmp);
            if (aux != 0) {

              if (frame.targetted == 1) {
                return frame.return_value;
              } else {
                rb_jump_tag(aux);
              }
            }

            return #{inner_code};
            }
          "
        }

        rescue_args = "(VALUE)pframe"
      end

      wrapper_code = "        if (state != 0) {
          if (state < 0x80) {

            if (state == TAG_RAISE) {
                // raise emulation
                pframe->thread_data->exception = rb_eval_string(\"$!\");
                longjmp(pframe->jmp, FASTRUBY_TAG_RAISE);
                return Qnil;
            } else {
              rb_jump_tag(state);
            }
          } else {
            longjmp(pframe->jmp, state);
          }

        }
        "

      rescue_code = "rb_protect(#{body},#{rescue_args},&state)"

      if always_rescue
        inline_block "
          int state;
          pframe->last_error = Qnil;
          VALUE result = #{rescue_code};

          #{wrapper_code}

          return result;
        ", repass_var, nolocals
      else
        inline_block "
          VALUE result;
          int state;
          pframe->last_error = Qnil;

          if (pframe->rescue) {
            result = #{rescue_code};
            #{wrapper_code}
          } else {
            return #{inner_code};
          }

          return result;
        ", repass_var, nolocals
      end
    end

    def func_frame
      "
        #{@locals_struct} *plocals = malloc(sizeof(typeof(*plocals)));
        #{@frame_struct} frame;
        #{@frame_struct} *pframe;

        frame.plocals = plocals;
        frame.parent_frame = (void*)_parent_frame;
        frame.return_value = Qnil;
        frame.rescue = 0;
        frame.targetted = 0;
        frame.thread_data = ((typeof(pframe))_parent_frame)->thread_data;
        if (frame.thread_data == 0) frame.thread_data = rb_current_thread_data();

        plocals->pframe = LONG2FIX(&frame);
        plocals->targetted = Qfalse;

        pframe = (void*)&frame;

        #{@block_struct} *pblock;
        VALUE last_expression = Qnil;

        int aux = setjmp(pframe->jmp);
        if (aux != 0) {

          if (plocals->targetted == Qfalse) {
            longjmp(((typeof(pframe))_parent_frame)->jmp,aux);
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
      address_name = self.add_global_name("void**", 0);
      @last_address_name = address_name
      cfunc_address_name = self.add_global_name("void**", 0);
      cfunc_real_address_name  = self.add_global_name("void*", 0);
      tree_pointer_name = self.add_global_name("VALUE*", 0);
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

      value_cast = ( ["VALUE"]*(args_tree.size) ).join(",") + ",VALUE,VALUE"

      recvdump = nil

      begin
         recvdump = literal_value recvtype
      rescue
      end
      
      pureruby_wrapper = anonymous_function{ |funcname| "
        static VALUE #{funcname}(VALUE self,void* block,void* frame#{strargs_signature}){
          #{@frame_struct}* pframe = frame;
          VALUE method_arguments[#{args_tree.size}] = {#{toprocstrargs}};
  
          return #{
            protected_block "rb_funcall(((VALUE*)method_arguments)[0], #{intern_num mname.to_sym}, #{args_tree.size-1}#{inprocstrargs});", false, "method_arguments"
            };
        }
      "
      }
      
      generic_wrapper = anonymous_function{ |funcname| "
        static VALUE #{funcname}(VALUE self,void* block,void* frame#{strargs_signature}){
        
          #{@frame_struct}* pframe = frame;
          VALUE method_arguments[#{args_tree.size}] = {#{toprocstrargs}};
          
          void* fptr = 0;
          
          if (*#{address_name} == 0) {
            if (#{tree_pointer_name} != 0) {
              if (*#{tree_pointer_name} != Qnil) {
                VALUE signature = #{literal_value signature};
                VALUE recvtype = #{recvdump};
                VALUE mname = #{literal_value mname};
                
                rb_funcall(recvtype, #{intern_num :build}, 2, signature, mname);
              }
            }
          }
          
          fptr = *#{address_name};
          
          #{
            if args_tree.size < 25
            "
            if (fptr == 0) {
              fptr = *#{cfunc_address_name};
              if (fptr != 0) {
                VALUE params[2] = {self,LONG2FIX(#{args_tree.size-1})};
                return ( (VALUE(*)(#{value_cast})) (fptr) )((VALUE)params,(VALUE)block,(VALUE)frame#{inprocstrargs});  
              }
            }
            "
            end
          } 
          
          if (fptr == 0) {
            return #{
              protected_block "rb_funcall(((VALUE*)method_arguments)[0], #{intern_num mname.to_sym}, #{args_tree.size-1}#{inprocstrargs});", false, "method_arguments"
              };
          } else {
            return ( (VALUE(*)(#{value_cast})) (fptr) )(self,(VALUE)block,(VALUE)frame#{inprocstrargs});  
          }
        }
        "
      }


      cfunc_value_cast = (["VALUE"]*args_tree.size).join(",")
      cfunc_wrapper = anonymous_function{ |funcname| "
        static VALUE #{funcname}(VALUE* params, void* block,void* frame#{strargs_signature}){
            VALUE self = params[0];
            VALUE method_arguments[#{args_tree.size}] = {#{toprocstrargs}};
            return ( (VALUE(*)(#{cfunc_value_cast})) (#{cfunc_real_address_name}) )(self#{inprocstrargs});
        }
        "
      }
      
      toprocstrargs = (0..25).map{|x| "arg#{x}"}.join(",")
      strargs_signature = (0..25).map{|x| "VALUE arg#{x}"}.join(",")

      cfunc_wrapper_1 = anonymous_function{ |funcname| "
        static VALUE #{funcname}(VALUE* params, void* block,void* frame, #{strargs_signature}){
            VALUE self = params[0];
            VALUE method_arguments[26] = {#{toprocstrargs}};
            return ( (VALUE(*)(int, VALUE*, VALUE)) (#{cfunc_real_address_name}) )(FIX2LONG(params[1]),method_arguments,self);
        }
        "
      }

      cfunc_wrapper_2 = anonymous_function{ |funcname| "
        static VALUE #{funcname}(VALUE* params, void* block,void* frame, #{strargs_signature}){
            VALUE self = params[0];
            VALUE args = rb_ary_new3(FIX2LONG(params[1]),#{toprocstrargs});
            return ( (VALUE(*)(VALUE,VALUE)) (#{cfunc_real_address_name}) )(self,args);
        }
        "
      }

      if recvdump and recvtype
        init_extra << "
          {
            VALUE recvtype = #{recvdump};
            rb_funcall(#{literal_value FastRuby}, #{intern_num :set_builder_module}, 1, recvtype);
            VALUE signature = #{literal_value signature};
            VALUE mname = #{literal_value mname};
            VALUE tree = #{literal_value method_tree};
            VALUE rb_str_signature = rb_funcall(
                                      #{literal_value FastRuby},
                                      #{intern_num :make_str_signature},
                                      2,
                                      mname,
                                      signature);



            VALUE fastruby_method = rb_funcall(recvtype, #{intern_num :fastruby_method}, 1, mname);
            #{tree_pointer_name} = (VALUE*)FIX2LONG(fastruby_method_tree_pointer(fastruby_method));
            
            ID id;
            ID default_id = rb_intern(\"default\");
            VALUE rb_method_hash;
            void** address = 0;
            void** default_address = 0;
            id = rb_intern(RSTRING(rb_str_signature)->ptr);
            rb_method_hash = rb_funcall(recvtype, #{intern_num :method_hash},1,mname);

            if (rb_method_hash != Qnil) {
              VALUE tmp = rb_hash_aref(rb_method_hash, LONG2FIX(id));
              if (tmp != Qnil) {
                  address = (void*)FIX2LONG(tmp);
              }
              
              tmp = rb_hash_aref(rb_method_hash, LONG2FIX(default_id));
              if (tmp != Qnil) {
                 default_address = (void*)FIX2LONG(tmp);
              }
            }
            
            if (default_address==0) {
              default_address = malloc(sizeof(void*));
              NODE* body = rb_method_node(recvtype,#{intern_num mname});
              *default_address = 0;
              
              if (body != 0) {
                if (nd_type(body) == NODE_CFUNC) {
                  if (body->nd_argc == #{args_tree.size-1}) {
                    *default_address = #{cfunc_wrapper};
                    #{cfunc_real_address_name} = (void*)body->nd_cfnc;
                  } else if (body->nd_argc == -1) {
                    *default_address = #{cfunc_wrapper_1};
                    #{cfunc_real_address_name} = (void*)body->nd_cfnc;
                  } else if (body->nd_argc == -2) {
                    *default_address = #{cfunc_wrapper_2};
                    #{cfunc_real_address_name} = (void*)body->nd_cfnc;
                  }
                }
              }
            
              if (recvtype != Qnil) { 
                rb_funcall(
                    recvtype,
                    #{intern_num :register_method_value}, 
                    3,
                    #{literal_value mname},
                    LONG2FIX(default_id),
                    LONG2FIX(default_address)
                    );
              }
            }

            if (address==0) {
              address = malloc(sizeof(void*));
              
              if (recvtype != Qnil) { 
                rb_funcall(
                    recvtype,
                    #{intern_num :register_method_value}, 
                    3,
                    #{literal_value mname},
                    LONG2FIX(id),
                    LONG2FIX(address)
                    );
              }
  
              *address = 0; //(void*)
            }
            
            #{address_name} = address;
            #{cfunc_address_name} = default_address;
            #{name} = (void*)#{generic_wrapper};
          }
        "
      else
        init_extra << "
        // ruby, wrap rb_funcall
        #{name} = (void*)#{pureruby_wrapper};
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

          frame.parent_frame = (void*)param;
          frame.plocals = parent_frame->plocals;
          frame.rescue = #{rescued ? rescued : "parent_frame->rescue"};
          frame.targetted = 0;
          frame.thread_data = parent_frame->thread_data;
          if (frame.thread_data == 0) frame.thread_data = rb_current_thread_data();

          plocals = frame.plocals;
          pframe = &frame;

          int aux = setjmp(frame.jmp);
          if (aux != 0) {
            last_expression = pframe->return_value;

            // restore previous frame
            typeof(pframe) original_frame = pframe;
            pframe = parent_frame;

            #{jmp_code};

            if (original_frame->targetted == 0) {
              longjmp(pframe->jmp,aux);
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
