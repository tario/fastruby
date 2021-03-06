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
require "fastruby/translator/scope_mode_helper"
require "fastruby/modules"
require "define_method_handler"
require "base64"

module FastRuby
  class Context
    attr_accessor :locals
    attr_accessor :options
    attr_reader :no_cache
    attr_reader :init_extra
    attr_reader :extra_code
    
    class Value
      attr_accessor :value
      def initialize(v); @value = v; end
    end
    
    def self.define_translator_for(ntype, options = {}, &blk)
      condition_blk = proc do |*x|
        tree = x.first; tree.node_type == ntype
      end
      
      if options[:arity]
        if options[:arity] == 1
          condition_blk = proc do |*x|
            tree = x.first; x.size == 1 and tree.node_type == ntype
          end
        end
      end
      
      define_method_handler(:to_c, options, &blk).condition &condition_blk
    end

    define_method_handler(:to_c, :priority => 10000){|*x|
        "Qnil"
      }.condition{|*x| x.size == 1 and (not x.first)}

    define_method_handler(:to_c, :priority => 1000){|tree, result_var|
        "#{result_var} = #{to_c(tree)};"
      }.condition{|*x| x.size == 2 and (not x.first)}

    define_method_handler(:to_c, :priority => -9000){ |tree, result_var|
      "#{result_var} = #{to_c(tree)};"
    }.condition{|*x| x.size == 2 }
    
    define_method_handler(:to_c, :priority => -10000) do |*x|
      tree, result_var = x

      raise "undefined translator for node type :#{tree.node_type}"
    end
    
    define_method_handler(:initialize_to_c){|*x|}.condition{|*x|false}

    define_translator_for(:call, :priority => 100){ |*x|
      tree, result_var = x

      tree[2] = :fastruby_require
      to_c(tree)
    }.condition{|*x|
      tree = x.first; tree.node_type == :call && tree[2] == :require
    }
    
    define_method_handler(:infer_value, :priority => -1000) do |tree|
      nil
    end
    
    FastRuby::Modules.load_all("translator")
    
    def catch_block(*catchs)
        old_catch_blocks = @catch_blocks.dup
      begin
        catchs.each &@catch_blocks.method(:<<)
        return yield
      ensure
        @catch_blocks = old_catch_blocks
      end
    end

    def initialize(common_func = true, inferencer = nil)
      initialize_to_c
      
      @inferencer = inferencer
      @catch_blocks = []
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
        VALUE proc;
      }"

        extra_code << "
          static void frb_jump_tag(int state) {
            VALUE exception = rb_funcall(#{literal_value FastRuby::JumpTagException}, #{intern_num :new},1,INT2FIX(state)); 
            rb_exc_raise(exception);
          }
        "

      extra_code << "
        #define FASTRUBY_TAG_RETURN 0x80
        #define FASTRUBY_TAG_NEXT 0x81
        #define FASTRUBY_TAG_BREAK 0x82
        #define FASTRUBY_TAG_RAISE 0x83
        #define FASTRUBY_TAG_REDO 0x84
        #define FASTRUBY_TAG_RETRY 0x85
        #define TAG_RAISE 0x6

# define PTR2NUM(x)   (ULONG2NUM((unsigned long)(x)))
# define NUM2PTR(x)   ((void*)(NUM2ULONG(x)))

        #ifndef __INLINE_FASTRUBY_BASE
        #include \"#{FastRuby.fastruby_load_path}/../ext/fastruby_base/fastruby_base.inl\"
        #define __INLINE_FASTRUBY_BASE
        #endif
      "

      ruby_code = "
        unless $LOAD_PATH.include? #{FastRuby.fastruby_load_path.inspect}
          $LOAD_PATH << #{FastRuby.fastruby_load_path.inspect}
        end
        require #{FastRuby.fastruby_script_path.inspect}
      "

      init_extra << "
        rb_eval_string(#{ruby_code.inspect});
    	"
	
	
      if RUBY_VERSION =~ /^1\.8/

      @lambda_node_gvar = add_global_name("NODE*", 0);
      @proc_node_gvar = add_global_name("NODE*", 0);
      @procnew_node_gvar = add_global_name("NODE*", 0);
      @callcc_node_gvar = add_global_name("NODE*", 0);
      
      init_extra << "
        #{@lambda_node_gvar} = rb_method_node(rb_cObject, #{intern_num :lambda});
        #{@proc_node_gvar} = rb_method_node(rb_cObject, #{intern_num :proc});
        #{@procnew_node_gvar} = rb_method_node(CLASS_OF(rb_cProc), #{intern_num :new});
        #{@callcc_node_gvar} = rb_method_node(rb_mKernel, #{intern_num :callcc});
      "
     elsif RUBY_VERSION =~ /^1\.9/

      @lambda_node_gvar = add_global_name("void*", 0);
      @proc_node_gvar = add_global_name("void*", 0);
      @procnew_node_gvar = add_global_name("void*", 0);
      @callcc_node_gvar = add_global_name("void*", 0);
      
      init_extra << "
        #{@lambda_node_gvar} = rb_method_entry(rb_cObject, #{intern_num :lambda});
        #{@proc_node_gvar} = rb_method_entry(rb_cObject, #{intern_num :proc});
        #{@procnew_node_gvar} = rb_method_entry(CLASS_OF(rb_const_get(rb_cObject, #{intern_num :Proc})), #{intern_num :new});
        #{@callcc_node_gvar} = rb_method_entry(rb_mKernel, #{intern_num :callcc});
      "
	   end

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

         return #{protected_block("last_expression = rb_yield_splat(*(VALUE*)yield_args_p)",true,"yield_args_p",true)};
        }"

        extra_code << "static VALUE _rb_ivar_set(VALUE recv,ID idvar, VALUE value) {
          rb_ivar_set(recv,idvar,value);
          return value;
        }
        "

        extra_code << "static VALUE __rb_cvar_set(VALUE recv,ID idvar, VALUE value, int warn) {
          #{if RUBY_VERSION =~ /^1\.9/
            "rb_cvar_set(recv,idvar,value);"
            elsif RUBY_VERSION =~ /^1\.8/
            "rb_cvar_set(recv,idvar,value,warn);"
            else
              raise RuntimeError, "unsupported ruby version #{RUBY_VERSION}"
            end 
          }
         
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


    def _raise(class_tree, message_tree = nil)
      @has_raise = true
      @has_inline_block = true
      class_tree = to_c class_tree unless class_tree.instance_of? String

      if message_tree.instance_of? String
        message_tree = "rb_str_new2(#{message_tree.inspect})"
      else
        message_tree = to_c message_tree
      end

      if message_tree
        return inline_block("
            pframe->thread_data->exception = rb_funcall(#{class_tree}, #{intern_num :exception},1,#{message_tree});
            longjmp(pframe->jmp, FASTRUBY_TAG_RAISE);
            return Qnil;
            ")
      else
        return inline_block("
            pframe->thread_data->exception = rb_funcall(#{class_tree}, #{intern_num :exception},0);
            longjmp(pframe->jmp, FASTRUBY_TAG_RAISE);
            return Qnil;
            ")
      end

    end
    
    def anonymous_function(*x)

      name = "anonymous" + rand(10000000).to_s
      extra_code << yield(name,*x)

      name
    end

    def frame_call(inner_code, precode = "", postcode = "")
      inline_block "

        volatile VALUE ret = Qnil;
        // create a call_frame
        #{@frame_struct} call_frame;
        typeof(call_frame)* volatile old_pframe = (void*)pframe;

        pframe = (typeof(pframe))&call_frame;

        call_frame.parent_frame = (void*)pframe;
        call_frame.plocals = plocals;
        call_frame.return_value = Qnil;
        call_frame.targetted = 0;
        call_frame.thread_data = old_pframe->thread_data;
        if (call_frame.thread_data == 0) call_frame.thread_data = rb_current_thread_data();

        void* volatile old_call_frame = plocals->call_frame;
        plocals->call_frame = &call_frame;

        #{precode}

                int aux = setjmp(call_frame.jmp);
                if (aux != 0) {
                  if (call_frame.targetted == 0) {
                    #{postcode}
                    longjmp(old_pframe->jmp,aux);
                  }

                  if (aux == FASTRUBY_TAG_BREAK) {
                    plocals->call_frame = old_call_frame;
                    #{postcode}
                    return call_frame.return_value;
                  } else if (aux == FASTRUBY_TAG_RETRY ) {
                    // do nothing and let the call execute again
                  } else {
                    plocals->call_frame = old_call_frame;
                    #{postcode}
                    return call_frame.return_value;
                  }
                }
                

        #{inner_code};
        
        #{postcode}
        
        plocals->call_frame = old_call_frame;
        return ret;
      "
    end

    def initialize_method_structs(args_tree)
      @locals = options[:locals] if options[:locals]

      @locals_struct = options[:locals_struct] || "struct {
        int size;        
        void* call_frame;
        void* parent_locals;
        void* pframe;
        void* block_function_address;
        void* block_function_param;
        VALUE active;
        VALUE targetted;
        VALUE return_value;
        VALUE __dynavars;
        #{@locals.map{|l| "VALUE #{l};\n"}.join}
        }"

    end

    def add_main
      if options[:main]

        extra_code << "
          static VALUE #{@alt_method_name}(VALUE self__);
          static VALUE main_proc_call(VALUE self__, VALUE signature, VALUE class_self_) {
            #{@alt_method_name}(class_self_);
            return Qnil;
          }

        "

        init_extra << "
            {
            VALUE newproc = rb_funcall(rb_cObject,#{intern_num :new},0);
            rb_define_singleton_method(newproc, \"call\", main_proc_call, 2);
            rb_gv_set(\"$last_obj_proc\", newproc);
            }
          "
      end
    end

    def define_method_at_init(method_name, size, signature)
      extra_code << "
        static VALUE main_proc_call(VALUE self__, VALUE signature, VALUE class_self_) {
          VALUE method_name = rb_funcall(
                #{literal_value FastRuby},
                #{intern_num :make_str_signature},
                2,
                #{literal_value method_name},
                signature
                );

          ID id = rb_intern(RSTRING_PTR(method_name));
          
          rb_funcall(
                #{literal_value FastRuby},
                #{intern_num :set_builder_module},
                1,
                class_self_
                );
          
          VALUE rb_method_hash;
          void** address = 0;
          rb_method_hash = rb_funcall(class_self_, #{intern_num :method_hash},1,#{literal_value method_name});

          if (rb_method_hash != Qnil) {
            VALUE tmp = rb_hash_aref(rb_method_hash, PTR2NUM(id));
            if (tmp != Qnil) {
                address = (void*)NUM2PTR(tmp);
            }
          }
          
          if (address == 0) {
            address = malloc(sizeof(void*));
          }
          *address = #{@alt_method_name};
          
          rb_funcall(
              class_self_,
              #{intern_num :register_method_value}, 
              3,
              #{literal_value method_name},
              PTR2NUM(id),
              PTR2NUM(address)
              );
              
              return Qnil;
        }
      "
      
      init_extra << "
            {
            VALUE newproc = rb_funcall(rb_cObject,#{intern_num :new},0);
            rb_define_singleton_method(newproc, \"call\", main_proc_call, 2);
            rb_gv_set(\"$last_obj_proc\", newproc);
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

      @method_arguments = original_args_tree[1..-1]
      
      if "0".respond_to?(:ord)
        @alt_method_name = "_" + method_name.to_s.gsub("_x_", "_x__x_").gsub(/\W/){|x| "_x_#{x.ord}" } + "_" + rand(10000000000).to_s
      else
        @alt_method_name = "_" + method_name.to_s.gsub("_x_", "_x__x_").gsub(/\W/){|x| "_x_#{x[0]}" } + "_" + rand(10000000000).to_s
      end

        @has_yield = false
        @has_dynamic_call = false
        @has_nonlocal_goto = false
        @has_inline_block = (options[:main] or tree.find_tree(:lasgn))
        @has_plocals_ref = false
        @has_raise = false
        @has_inline_c = false

      args_tree = original_args_tree.select{|x| x.to_s[0] != ?&}

        initialize_method_structs(original_args_tree)
        
        if options[:main] then
          strargs = if args_tree.size > 1
            "VALUE self, VALUE block, VALUE _parent_frame, #{(0..signature.size-1).map{|x| "VALUE arg#{x}"}.join(",")}"
          else
            "VALUE self, VALUE block, VALUE _parent_frame"
          end

        else
          
          strargs = "VALUE self, VALUE block, VALUE _parent_frame, int argc, VALUE* argv"
          
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
                  unless subtree.to_s.match(/\*/) or subtree.to_s.match(/\&/)
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
                      "plocals->#{arg} = argv[#{i}];\n"
                    else
                        
                      if default_block_tree
                        @has_inline_block = true
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
                    @has_splat_args = true
                    if signature.size-1 < normalargsnum then
                      read_arguments_code << "
                        plocals->#{splat_arg.to_s.gsub("*","")} = rb_ary_new3(0);
                        "
                    else
                      read_arguments_code << "
                        plocals->#{splat_arg.to_s.gsub("*","")} = rb_ary_new4(
                              #{(signature.size-1) - (normalargsnum)}, argv+#{normalargsnum} 
                              );
                      "
                    end
      
              end
            
            
              ""
          end
  
          if block_argument

            @has_yield = true
  
            proc_reyield_block_tree = s(:iter, s(:call, nil, :proc, s(:arglist)), s(:masgn, s(:array, s(:splat, s(:lasgn, :__xproc_arguments)))), s(:yield, s(:splat, s(:lvar, :__xproc_arguments))))
  
            require "fastruby/sexp_extension"
  
            read_arguments_code << "
              if (pblock ? pblock->proc != Qnil : 0) {
                plocals->#{block_argument.to_s.gsub("&","")} = pblock->proc;
              } else {
                plocals->#{block_argument.to_s.gsub("&","")} = #{to_c FastRuby::FastRubySexp.from_sexp(proc_reyield_block_tree)};
              }
            "

            read_arguments_code << "
              if (pblock) {
              rb_ivar_set(plocals->#{block_argument.to_s.gsub("&","")},
                        #{intern_num "__block_address"}, PTR2NUM(pblock->block_function_address)); 
              rb_ivar_set(plocals->#{block_argument.to_s.gsub("&","")},
                        #{intern_num "__block_param"}, PTR2NUM(pblock->block_function_param));            
              }            

            "
          end

        end

        require "fastruby/sexp_extension"
        
        trs = lambda{|tree| 
            if not tree.respond_to? :node_type 
              next tree
            elsif tree.node_type == :call
              mmname = tree[2]
              next trs.call(tree[1]) || tree[1] if mmname == :infer
              next fs(:nil) if mmname == :_throw or mmname == :_loop or mmname == :_raise
              next fs(:nil) if mmname == :== and infer_value(tree)
            elsif tree.node_type == :iter
              mmname = tree[1][2]
              next fs(:nil) if mmname == :_static
              next fs(:block, trs.call(tree[3]) || tree[3]) if mmname == :_catch
            end

            tree.map &trs
          }
          
        evaluate_tree = tree.transform &trs

        impl_code = to_c(impl_tree, "last_expression")

        put_setjmp = (@has_dynamic_call or @has_nonlocal_goto or @has_yield or @has_raise or @has_inline_c)
        put_block_init = @has_yield
        if options[:main]
          put_block_init = false
        end

        scope_mode = @scope_mode || FastRuby::ScopeModeHelper.get_scope_mode(evaluate_tree)
        if scope_mode == :dag or put_setjmp or put_block_init or @has_splat_args
          put_frame = true
          put_locals = true
        else
          put_frame = @has_inline_block
          put_locals = @has_plocals_ref
        end

        ret = "VALUE #{@alt_method_name || method_name}(#{options[:main] ? "VALUE self" : strargs}) {
          #{validate_arguments_code}

#{if put_frame
"
          #{@frame_struct} frame;
          #{@frame_struct} * volatile pframe;
          
          frame.parent_frame = #{options[:main] ? "0"  : "(void*)_parent_frame"};
          frame.return_value = Qnil;
          frame.rescue = 0;
          frame.targetted = 0;
          frame.thread_data = #{options[:main] ? "0" : "((typeof(pframe))_parent_frame)->thread_data"};
          if (frame.thread_data == 0) frame.thread_data = rb_current_thread_data();
"
end
}
          
#{
if scope_mode == :dag
  " 
          int stack_chunk_instantiated = 0;

          volatile VALUE rb_previous_stack_chunk = Qnil;
          VALUE rb_stack_chunk = frame.thread_data->rb_stack_chunk;
          struct STACKCHUNK* volatile stack_chunk = 0;

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

          #{@locals_struct}* volatile plocals;

          volatile int previous_stack_position = stack_chunk_get_current_position(stack_chunk);
          plocals = (typeof(plocals))stack_chunk_alloc(stack_chunk ,sizeof(typeof(*plocals))/sizeof(void*));
          
  "
else
  "
          #{@locals_struct} locals;
          typeof(locals) * volatile plocals = &locals;
  "
end
}

#{if put_locals and put_frame
"
          plocals->parent_locals = (frame.thread_data->last_plocals);
          void* volatile old_parent_locals = frame.thread_data->last_plocals;
          
          #{
          if scope_mode == :dag 
            "frame.thread_data->last_plocals = plocals;\n"
          end
          }
          
          frame.plocals = plocals;
          plocals->pframe = (&frame);
          pframe = (void*)&frame;
"
end
}

#{if put_locals
"
          plocals->active = Qtrue;
          plocals->targetted = Qfalse;
          plocals->call_frame = (0);
"
end
}

          volatile VALUE last_expression = Qnil;

#{if put_setjmp
"

          int aux = setjmp(pframe->jmp);
          if (aux != 0) {
            plocals->active = Qfalse;

#{
if scope_mode == :dag
  " 
            stack_chunk_set_current_position(stack_chunk, previous_stack_position);

            if (stack_chunk_instantiated) {
              rb_gc_unregister_address(&rb_stack_chunk);
              frame.thread_data->rb_stack_chunk = rb_previous_stack_chunk;
            }
"
end
}            
            #{
            unless options[:main]
              "
              if (plocals->targetted == Qfalse || aux != FASTRUBY_TAG_RETURN) {
                frame.thread_data->last_plocals = old_parent_locals;
                
                longjmp(((typeof(pframe))_parent_frame)->jmp,aux);
              }
              "
            end
            }

            frame.thread_data->last_plocals = old_parent_locals;
            
            return plocals->return_value;
          }
"
end
}

#{if put_locals
"
          plocals->self = self;
"
end
}

          #{
          if put_block_init
            "
            #{@block_struct} * volatile pblock;
            pblock = (void*)block;
            if (pblock) {
              plocals->block_function_address = pblock->block_function_address;
              plocals->block_function_param = pblock->block_function_param;
            } else {
              plocals->block_function_address = (0);
              plocals->block_function_param = 0;
            }
            "
          end
          }

#{if put_locals
"
          #{read_arguments_code}
"
end
}

          #{impl_code};
          
local_return:
#{
if scope_mode == :dag
"
          stack_chunk_set_current_position(stack_chunk, previous_stack_position);

          if (stack_chunk_instantiated) {
            rb_gc_unregister_address(&rb_stack_chunk);
            frame.thread_data->rb_stack_chunk = rb_previous_stack_chunk;
          }
"
end
}

#{if put_locals
"
          plocals->active = Qfalse;
"
end
}          
          
#{if put_locals and put_frame
"
          frame.thread_data->last_plocals = old_parent_locals;
"
end
}          

          return last_expression;
        }"

        add_main
        extra_code << ret
      
      "
        static VALUE dummy_#{@alt_method_name}_#{rand(1000000000000000000000000000000000)}(VALUE a) {
          return Qnil;
        }
      "
    end

    def locals_accessor
      @has_plocals_ref = true
      "plocals->"
    end

    def locals_scope(locals)
       old_locals = @locals
       old_locals_struct = @locals_struct

       @locals = locals
        @locals_struct = options[:locals_struct] || "struct {
        int size;
        void* call_frame;
        void* parent_locals;
        void* pframe;
        void* block_function_address;
        void* block_function_param;
        VALUE active;
        VALUE targetted;
        VALUE return_value;
        VALUE __dynavars;
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
      array = @inferencer.infer(recv).to_a
      
      if array.size == 1
        array[0]
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
      elsif mname == :block_given?
        @has_yield = true
        return "plocals->block_function_address == 0 ? Qfalse : Qtrue"
      elsif mname == :inline_c
        @has_inline_c = true
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
      @has_inline_block = true

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

    def catch_on_throw
      old_catch_jmp_on_throw = @catch_jmp_on_throw || false
      @catch_jmp_on_throw = true
      begin
        ret = yield
      ensure
        @catch_jmp_on_throw = old_catch_jmp_on_throw
      end
      
      ret
    end

    def inline_block(*args)
      @has_inline_block = true
      
      unless block_given?
        code = args.first
        return inline_block(*args[1..-1]) {
            code
          }
      end
      
      repass_var = args[0]
      nolocals = args[1] || false
      
      code = catch_on_throw{ yield }

      anonymous_function{ |name| "
        static VALUE #{name}(VALUE param#{repass_var ? ",void* " + repass_var : "" }) {
          #{@frame_struct} * volatile pframe = (void*)param;

          #{nolocals ? "" : "#{@locals_struct} * volatile plocals = (void*)pframe->plocals;"}
          volatile VALUE last_expression = Qnil;

          #{code}
          return Qnil;


#{@catch_blocks.map { |cb|
  "#{cb.to_s}_end:

   plocals->return_value = last_expression;
   plocals->targetted = 1;
   longjmp(pframe->jmp, #{intern_num( cb.to_s + "_end")});
    
   #{cb.to_s}_start:
  
   plocals->return_value = last_expression;
   plocals->targetted = 1;
   longjmp(pframe->jmp, #{intern_num( cb.to_s + "_start")});
  
  "

}.join("\n")
}
          #{unless nolocals
          "
local_return:
        plocals->return_value = last_expression;
        plocals->targetted = 1;
        longjmp(pframe->jmp, FASTRUBY_TAG_RETURN);
        return last_expression;
        "
        end
          }
fastruby_local_redo:
          longjmp(pframe->jmp,FASTRUBY_TAG_REDO);
          return Qnil;
fastruby_local_next:
          longjmp(pframe->jmp,FASTRUBY_TAG_NEXT);
          return Qnil;


          }
        "
      } + "((VALUE)pframe#{repass_var ? ", " + repass_var : "" })"
    end

    def inline_ruby(proced, parameter)
      "rb_funcall(#{proced.__id__}, #{intern_num :call}, 1, #{parameter})"
    end

    def protected_block(*args)
      unless block_given?
        inner_code = args.first
        return protected_block(*args[1..-1]) {
          inner_code
        }
      end
      
      repass_var = args[1]
      nolocals = args[2] || false
      
      inline_block(repass_var, nolocals) do
        generate_protected_block(yield, *args)
      end
    end
    
    def generate_protected_block(inner_code, always_rescue = false,repass_var = nil, nolocals = false)
      body = nil
      rescue_args = nil

        body =  anonymous_function{ |name| "
          static VALUE #{name}(VALUE param) {

            #{@frame_struct} frame;

            typeof(frame)* volatile pframe;
            
            #{if repass_var
            "typeof(frame)* parent_frame = ((typeof(pframe))((void**)param)[0]);"
            else
            "typeof(frame)* parent_frame = (typeof(pframe))param;"
            end
            }

            frame.parent_frame = 0;
            frame.return_value = Qnil;
            frame.rescue = 0;
            frame.last_error = Qnil;
            frame.targetted = 0;
            frame.thread_data = parent_frame->thread_data;
            frame.next_recv = parent_frame->next_recv;
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
                frb_jump_tag(aux);
              }
            }

            #{if repass_var 
              "VALUE #{repass_var} = (VALUE)((void**)param)[1];"
            end
            }
              volatile VALUE last_expression = Qnil;
              #{inner_code};
              return last_expression;
            }
          "
        }

      if repass_var
        rescue_args = ""
        rescue_args = "(VALUE)(VALUE[]){(VALUE)pframe,(VALUE)#{repass_var}}"
      else
        rescue_args = "(VALUE)pframe"
      end

      wrapper_code = "
            if (str.state >= 0x80) {
              longjmp(pframe->jmp, str.state);
            } else {
              if (str.last_error != Qnil) {
                  // raise emulation
                  pframe->thread_data->exception = str.last_error;
                  longjmp(pframe->jmp, FASTRUBY_TAG_RAISE);
                  return Qnil;
              }
            }
        "
        
        return_err_struct = "struct {
            VALUE last_error;
            int state;
          }
          "

        rescue_body = anonymous_function{ |name| "
          static VALUE #{name}(VALUE param, VALUE err) {
            #{return_err_struct} *pstr = (void*)param;
            
            if (rb_obj_is_instance_of(err, #{literal_value FastRuby::JumpTagException})) {
              pstr->state = FIX2INT(rb_funcall(err, #{intern_num :state}, 0));
            } else {
              pstr->last_error = err;
            }
            
            return Qnil;
          }
        "
      }

      rescue_code = "rb_rescue2(#{body}, #{rescue_args}, #{rescue_body}, (VALUE)&str, rb_eException, (VALUE)0)"

      if always_rescue
        "
          #{return_err_struct} str;
          
          str.state = 0;
          str.last_error = Qnil;
          
          pframe->last_error = Qnil;
          VALUE result = #{rescue_code};

          #{wrapper_code}

          return result;
        "
      else
        "
          VALUE result;
          #{return_err_struct} str;
          
          str.state = 0;
          str.last_error = Qnil;
          
          pframe->last_error = Qnil;

          if (pframe->rescue) {
            result = #{rescue_code};
            #{wrapper_code}
          } else {
            VALUE last_expression = Qnil;
            #{inner_code};
            return last_expression;
          }

          return result;
        "
      end
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

          str_class_name = value.to_s.split("::").last

          if (str_class_name == "Object")
            init_extra << "
              #{name} = rb_cObject;
            "
          else
            init_extra << "
              #{name} = rb_define_class_under(
                      #{container_str == "" ? "rb_cObject" : literal_value(eval(container_str))}
                      ,\"#{str_class_name}\"
                      ,#{value.superclass == Object ? "rb_cObject" : literal_value(value.superclass)});

              rb_funcall(#{name},#{intern_num :gc_register_object},0);
            "
          end
        elsif value.instance_of? Array
          init_extra << "
            #{name} = rb_ary_new3(#{value.size}, #{value.map{|x| literal_value x}.join(",")} );
            rb_funcall(#{name},#{intern_num :gc_register_object},0);
          "
        else
          
          init_extra << "
          
            {
              VALUE encoded_str = rb_str_new2(#{Base64.encode64(str).inspect});
              VALUE str = rb_funcall(rb_cObject, #{intern_num :decode64}, 1, encoded_str);
              #{name} = rb_marshal_load(str);
              
              rb_funcall(#{name},#{intern_num :gc_register_object},0);
            }

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
    
    def dynamic_block_call(signature, mname)
      dynamic_call(signature, mname, true)
    end

    # returns a anonymous function who made a dynamic call
    def dynamic_call(signature, mname, return_on_block_call = false, funcall_fallback = true, global_klass_variable = nil)
      # TODO: initialize the table
      @has_dynamic_call = true
      max_argument_size = 0
      recvtype = signature.first

      unless recvtype
        max_argument_size = max_argument_size + 1
      end

      compare_hash = {}
      (1..signature.size-1).each do |j|
        unless signature[j]
          compare_hash[max_argument_size] = j-1
          max_argument_size = max_argument_size + 1
        end
      end

      table_size = if compare_hash.size == 0
        1
      elsif compare_hash.size == 1
        16
      else
        64
      end

      table_name = reserve_table(table_size, max_argument_size)

      if recvtype
        
        init_extra << "{
          memset(#{table_name},0,sizeof(#{table_name}));
        
          VALUE mname = #{literal_value mname};
          VALUE recvtype = #{literal_value recvtype};
          rb_funcall(#{literal_value FastRuby}, #{intern_num :set_builder_module}, 1, recvtype);
          VALUE fastruby_method = rb_funcall(recvtype, #{intern_num :fastruby_method}, 1, mname);      
          rb_iterate(#{anonymous_function{|funcname|
            "static VALUE #{funcname}(VALUE recv) {
              return rb_funcall(recv, #{intern_num :observe}, 1, #{literal_value(mname.to_s + "#" + table_name.to_s)});
            }
            "
          }},fastruby_method,
            #{anonymous_function{|funcname|
              "static VALUE #{funcname}() {
                // clear table
                memset(#{table_name},0,sizeof(#{table_name}));
                return Qnil;
              }
              " 
            }
            }
          ,Qnil);
        }
        "
      else
        
        # TODO: implemente this in ruby
        init_extra << "
        {
          memset(#{table_name},0,sizeof(#{table_name}));
        
          rb_iterate(#{anonymous_function{|funcname|
            "static VALUE #{funcname}(VALUE recv) {
              return rb_funcall(recv, #{intern_num :observe_method_name}, 1, #{literal_value(mname.to_sym)});
            }
            "
          }},#{literal_value FastRuby::Method},
            #{anonymous_function{|funcname|
              "static VALUE #{funcname}() {
                // clear table
                memset(#{table_name},0,sizeof(#{table_name}));
                return Qnil;
              }
              " 
            }
            }
          ,Qnil);
          
        }
        "
          
      end

      anonymous_function{|funcname| "
        static VALUE #{funcname}(VALUE self,void* block,void* frame, int argc, VALUE* argv #{return_on_block_call ? ", int* block_call" : ""}){
          void* fptr = 0;
          #{if global_klass_variable
          "
          VALUE klass = #{global_klass_variable};
          "
          else
          "
          VALUE klass = CLASS_OF(self);
          "
          end
          }

          char method_name[argc*40+64];
          
          unsigned int fptr_hash = 0;
          int match = 1;

          #{if table_size > 1
          "
            #{unless signature.first
              "fptr_hash = klass;
              "
            end
            }
            
            #{
            compare_hash.map { |k,v|
              "if (#{v} < argc) {
                   fptr_hash += CLASS_OF(argv[#{v}]);
              }
              "
            }.join("\n")
            };

            fptr_hash = fptr_hash % #{table_size};

            int j = 0;

            if (argc+15 != #{table_name}[fptr_hash].argc) {
              match = 0;
              goto does_not_match;
            }

            #{unless recvtype
              "
              if (match == 1 && #{table_name}[fptr_hash].argument_type[0] != klass ) {
                match = 0;
                goto does_not_match;
              }
              "
            end
            }

            #{
            compare_hash.map { |k,v|
              "if (match == 1 && #{table_name}[fptr_hash].argument_type[#{k}] != CLASS_OF(argv[#{v}])) {
                 match = 0;
                 goto does_not_match;
              }
              "
            }.join("\n")
            };
          "
          end
          }

          if (#{table_name}[fptr_hash].address == 0) match = 0;
          if (match == 1) {
            fptr = #{table_name}[fptr_hash].address;
          } else {
does_not_match:
            method_name[0] = '_';
            method_name[1] = 0;
  
            strncpy(method_name+1, \"#{mname}\",sizeof(method_name)-4);
            sprintf(method_name+strlen(method_name), \"%li\", (long)NUM2PTR(rb_obj_id(CLASS_OF(self))));
            
                        int i;
                        for (i=0; i<argc; i++) {
                          sprintf(method_name+strlen(method_name), \"%li\", (long)NUM2PTR(rb_obj_id(CLASS_OF(argv[i]))));
                        }
  
            void** address = 0;
            ID id;
            VALUE rb_method_hash;
  
            id = rb_intern(method_name);

            VALUE parent_klass = klass;

            rb_method_entry_t *me;
#define UNDEFINED_METHOD_ENTRY_P(me) (!(me) || !(me)->def || (me)->def->type == VM_METHOD_TYPE_UNDEF)
            while (1) {
                
                if (rb_respond_to(parent_klass, #{intern_num :method_hash})) {
                  rb_method_hash = rb_funcall(parent_klass, #{intern_num :method_hash},1,#{literal_value mname});
                  
                  if (rb_method_hash != Qnil) {
                    VALUE tmp = rb_hash_aref(rb_method_hash, PTR2NUM(id));
                    if (tmp != Qnil) {
                        address = (void**)NUM2PTR(tmp);
                        fptr = *address;
                    }
                  }
                  
                  if (fptr == 0) {
                    VALUE fastruby_method = rb_funcall(parent_klass, #{intern_num :fastruby_method}, 1, #{literal_value mname});
                    VALUE tree = rb_funcall(fastruby_method, #{intern_num :tree}, 0,0);
        
                    if (RTEST(tree)) {
                      VALUE argv_class[argc+1];
                                    
                      argv_class[0] = CLASS_OF(self); 
                      for (i=0; i<argc; i++) {
                      argv_class[i+1] = CLASS_OF(argv[i]);
                      }
                                    
                      VALUE signature = rb_ary_new4(argc+1,argv_class);
                      
                      rb_funcall(parent_klass, #{intern_num :build}, 2, signature,rb_str_new2(#{mname.to_s.inspect}));
            
                      id = rb_intern(method_name);
                      rb_method_hash = rb_funcall(parent_klass, #{intern_num :method_hash},1,#{literal_value mname});
                      
                      if (rb_method_hash != Qnil) {
                        VALUE tmp = rb_hash_aref(rb_method_hash, PTR2NUM(id));
                        if (tmp != Qnil) {
                            address = (void**)NUM2PTR(tmp);
                            fptr = *address;
                        }
                      }
                      
                      if (fptr == 0) {
                        rb_raise(rb_eRuntimeError, \"Error: method not found after build\");
                      }
                    }
                  }
                }

                if (fptr != 0) break;

                st_data_t body;
                if (st_lookup(RCLASS_M_TBL(parent_klass), #{intern_num mname.to_sym}, &body)) {
                   break;
                }

                if (parent_klass == rb_cObject) break;
                parent_klass = rb_funcall(parent_klass, #{intern_num :superclass}, 0);

            }

            // insert the value on table
            #{table_name}[fptr_hash].argc = argc+15;

            #{unless recvtype
              "
              #{table_name}[fptr_hash].argument_type[0] = klass;
              "
            end
            }

            #{
            compare_hash.map { |k,v|
              "if (#{v} < argc) { 
                #{table_name}[fptr_hash].argument_type[#{k}] = CLASS_OF(argv[#{v}]);
              }
              "
            }.join("\n")
            };

            #{table_name}[fptr_hash].address = fptr;
          }
          
          if (fptr != 0) {
            return ((VALUE(*)(VALUE,VALUE,VALUE,int,VALUE*))fptr)(self,(VALUE)block,(VALUE)frame, argc, argv);
          }

          #{if funcall_fallback
          "
       
            #{@frame_struct}* pframe = frame;
            VALUE method_arguments[4];
            
            method_arguments[0] = (VALUE)argc;
            method_arguments[1] = (VALUE)argv;
            method_arguments[2] = (VALUE)self;
            method_arguments[3] = (VALUE)block;
              
              if (block == 0) {
                return #{
                  protected_block "
                    last_expression = rb_funcall2(((VALUE*)method_arguments)[2], #{intern_num mname.to_sym}, ((int*)method_arguments)[0], ((VALUE**)method_arguments)[1]);", true, "method_arguments"
                  };
            
              } else {
                #{
                if return_on_block_call
                  "*block_call = 1;
                  return Qnil;
                  "
                else
                  "
                  return #{
                      protected_block "
                            #{@block_struct} *pblock;
                            pblock = (typeof(pblock))( ((VALUE*)method_arguments)[3] );
                            last_expression = rb_iterate(
                            #{anonymous_function{|name_|
                              "
                                static VALUE #{name_} (VALUE data) {
                                  VALUE* method_arguments = (VALUE*)data;
                                  return rb_funcall2(((VALUE*)method_arguments)[2], #{intern_num mname.to_sym}, ((int*)method_arguments)[0], ((VALUE**)method_arguments)[1]);
                                }
                              "
                            }},
                              (VALUE)method_arguments,
                              
                            #{anonymous_function{|name_|
                              "
                                static VALUE #{name_} (VALUE arg_, VALUE param, int argc, VALUE* argv) {
                                #{@block_struct}* pblock = (void*)param;
                                
                                  if (pblock->proc != Qnil) {
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
              
                                    return rb_proc_call(pblock->proc, arg);
      
                                  } else {
                                      #{
                                      # TODO: access directly to argc and argv for optimal execution
                                      if RUBY_VERSION =~ /^1\.9/
                                        "return ((VALUE(*)(int,VALUE*,VALUE,VALUE))pblock->block_function_address)(argc,argv,(VALUE)pblock->block_function_param,(VALUE)0);" 
                                      else
                                        "return Qnil;"
                                      end
                                      }
                                  }
                                
                                }
                              "
                            }},
                              (VALUE)pblock
                            );
                    ", true, "method_arguments"
                    };
                  "
                end
                }
              }
            "
            else
            "
              rb_raise(rb_eRuntimeError, \"Error: invalid dynamic call for defn\");
              return Qnil;
            "
            end
          }
        }
        "
      }
    end

    def intern_num(symbol)
      symbol = symbol.to_sym
      @intern_num_hash = Hash.new unless @intern_num_hash
      return @intern_num_hash[symbol] if @intern_num_hash[symbol]

      name = self.add_global_name("ID", 0);

      init_extra << "
        #{name} = rb_intern(\"#{symbol.to_s}\");
      "

      @intern_num_hash[symbol] = name

      name
    end
    
    def reserve_table(size, argument_count)
      name = "glb_table" + rand(1000000000).to_s
      
      extra_code << "
        static struct {
          VALUE argument_type[#{argument_count}];
          void* address;
          int argc;
        } #{name}[#{size}];
      "
      
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
          volatile VALUE last_expression = Qnil;
          #{@frame_struct} frame;

          typeof(frame)* volatile pframe;
          typeof(frame)* volatile parent_frame;
          #{@locals_struct}* volatile plocals;

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
          volatile typeof(pframe) original_frame = pframe;
          pframe = parent_frame;
          #{not_jmp_code};

          return last_expression;

          }
        "
      } + "((VALUE)pframe)"
    end
  end
end
