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
    
    define_translator_for(:return, :method => :to_c_return)
    def to_c_return(tree, return_variable = nil)
      code = proc{"
        #{to_c(tree[1],"last_expression")};
        goto local_return;
        return Qnil;
        "}
        
      if return_variable
        code.call
      else
        inline_block &code
      end
    end

    define_translator_for(:break, :method => :to_c_break)
    def to_c_break(tree, result_var = nil)
      
        value_tmp_var = "value_" + rand(10000000).to_s
      
        code = proc{"

          {
         VALUE #{value_tmp_var} = Qnil; 
         #{
         if tree[1]
           to_c(tree[1], value_tmp_var)
         end
         };

         typeof(pframe) target_frame_;
         target_frame_ = (void*)plocals->call_frame;

         if (target_frame_ == 0) {
            #{_raise("rb_eLocalJumpError","illegal break")};
         }

         plocals->call_frame = 0;

         target_frame_->return_value = #{value_tmp_var};
         target_frame_->targetted = 1;
         pframe->thread_data->exception = Qnil;
         longjmp(pframe->jmp,FASTRUBY_TAG_BREAK);
         
         }
         "}
         
         if result_var
           code.call
         else
           inline_block code
         end
    end

    define_translator_for(:retry, :method => :to_c_retry)
    def to_c_retry(tree, result_var = nil)
        code = "
          {
         typeof(pframe) target_frame_;
         target_frame_ = (void*)plocals->call_frame;

         if (target_frame_ == 0) {
            #{_raise("rb_eLocalJumpError","illegal retry")};
         }

         target_frame_->targetted = 1;
         longjmp(pframe->jmp,FASTRUBY_TAG_RETRY);
         }
         "
       if result_var
         code
       else
         inline_block code
       end
    end

    define_translator_for(:redo, :method => :to_c_redo)
    def to_c_redo(tree, result_var = nil)
      if @on_block
         code = "
            goto fastruby_local_redo;
          "
          
          if result_var
            code
          else
            inline_block code
          end
      else
          _raise("rb_eLocalJumpError","illegal redo");
      end
    end

    define_translator_for(:next, :method => :to_c_next)
    def to_c_next(tree, result_var = nil)
      tmp_varname = "_acc_" + rand(10000000).to_s
      if @on_block
       code =proc {"
        {
          last_expression = Qnil;
          
          #{
          if tree[1]
            to_c(tree[1],"last_expression")
          end
          }
        pframe->thread_data->accumulator = last_expression;
        goto fastruby_local_next;
        }
        "}
        
        if result_var
          code.call
        else
          inline_block &code
        end
      else
        _raise("rb_eLocalJumpError","illegal next");
      end
    end
    
    define_method_handler(:to_c, :priority => 100) { |*x|
      tree, result_var  = x


      call_tree = tree[1]
      catch_tag_id = call_tree[3][1][1]
      included_catch_jmp = false

      @catch_jmp = @catch_jmp || Set.new
      
      begin
        inner_code = catch_block(catch_tag_id) do
          to_c(tree[3],result_var)
        end
        
        included_catch_jmp = true if @catch_jmp.include?(catch_tag_id) 
      ensure
        @catch_jmp.delete(catch_tag_id)
      end
      
      if included_catch_jmp
        new_frame = anonymous_function{ |name| "
          static VALUE #{name}(VALUE param) {
            volatile VALUE last_expression = Qnil;
            #{@frame_struct} frame;
  
            typeof(frame)* volatile pframe;
            typeof(frame)* volatile parent_frame;
            #{@locals_struct}* volatile plocals;
  
            parent_frame = (void*)param;
  
            frame.parent_frame = (void*)param;
            frame.plocals = parent_frame->plocals;
            frame.rescue = parent_frame->rescue;
            frame.targetted = 0;
            frame.thread_data = parent_frame->thread_data;
            frame.return_value = Qnil;
            frame.thread_data->accumulator = Qnil;
            if (frame.thread_data == 0) frame.thread_data = rb_current_thread_data();
  
            plocals = frame.plocals;
            pframe = &frame;
  
            volatile int aux = setjmp(frame.jmp);
            if (aux != 0) {
              // restore previous frame
              typeof(pframe) original_frame = pframe;
              pframe = parent_frame;

              if (aux == (int)#{intern_num catch_tag_id.to_s + "_end"}) {
                return frame.thread_data->accumulator;
              } else if (aux == (int)#{intern_num catch_tag_id.to_s + "_start"}) {
              } else {
                longjmp(pframe->jmp,aux);
              }
  
              return last_expression;
            }
            
         #{catch_tag_id.to_s}_start:
                #{inner_code};
          #{catch_tag_id.to_s}_end:
            return last_expression;
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
  
            }
          "
        } + "((VALUE)pframe)"
        
        if result_var
          "#{result_var} = #{new_frame};"
        else
          new_frame
        end
      else
          "
         #{catch_tag_id.to_s}_start:
                #{inner_code};
          #{catch_tag_id.to_s}_end:
          
          "
      end

    }.condition{|*x|
      tree, result_var  = x
 
      tree.node_type == :iter && tree[1][2] == :_catch
    }

    define_method_handler(:to_c, :priority => 100) { |*x|
      tree, result_var  = x

      code = ""
      
      catch_tag_id = tree[3][1][1]
      
      if @catch_jmp_on_throw
        @catch_jmp << catch_tag_id
      end
      
      code << to_c(tree[3][2] || fs(:nil), "last_expression")
      code << "pframe->thread_data->accumulator = last_expression;"
      code << "goto #{catch_tag_id.to_s}_end;"
      
      if result_var
        code
      else
        inline_block code
      end
    }.condition{|*x|
      tree, result_var  = x
 
      tree.node_type == :call && tree[2] == :_throw
    }
    
    define_method_handler(:to_c, :priority => 100) { |*x|
      tree, result_var  = x

      code = ""
      
      catch_tag_id = tree[3][1][1]
      code << "goto #{catch_tag_id.to_s}_start;"
      
      if result_var
        code
      else
        inline_block code
      end
    }.condition{|*x|
      tree, result_var  = x
 
      tree.node_type == :call && tree[2] == :_loop
    }

  end
end
