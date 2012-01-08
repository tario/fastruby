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
  module NonLocalTranslator
    register_translator_module self

    def to_c_return(tree, return_variable = nil)
      code = "
        #{to_c(tree[1],"last_expression")};
        goto local_return;
        return Qnil;
        "
      if return_variable
        code
      else
        inline_block code
      end
    end

    def to_c_break(tree, result_var = nil)
      
        value_tmp_var = "value_" + rand(10000000).to_s
      
        code = "

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
         "
         
         if result_var
           code
         else
           inline_block code
         end
    end

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

    def to_c_next(tree, result_var = nil)
      tmp_varname = "_acc_" + rand(10000000).to_s
      if @on_block
       code = "
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
        "
        if result_var
          code
        else
          inline_block code
        end
      else
        _raise("rb_eLocalJumpError","illegal next");
      end
    end

    
  end
end
