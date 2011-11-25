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

    def to_c_return(tree)
      inline_block "
        last_expression = #{to_c(tree[1])};
        goto local_return;
        return Qnil;
        "
    end

    def to_c_break(tree)
        inline_block(
         "

         VALUE value = #{tree[1] ? to_c(tree[1]) : "Qnil"};

         typeof(pframe) target_frame_;
         target_frame_ = (void*)FIX2LONG(plocals->call_frame);

         if (target_frame_ == 0) {
            #{_raise("rb_eLocalJumpError","illegal break")};
         }

         plocals->call_frame = LONG2FIX(0);

         target_frame_->return_value = value;
         target_frame_->targetted = 1;
         pframe->thread_data->exception = Qnil;
         longjmp(pframe->jmp,FASTRUBY_TAG_BREAK);"
        )
    end

    def to_c_retry(tree)
        inline_block(
         "
         typeof(pframe) target_frame_;
         target_frame_ = (void*)FIX2LONG(plocals->call_frame);

         if (target_frame_ == 0) {
            #{_raise("rb_eLocalJumpError","illegal retry")};
         }

         target_frame_->targetted = 1;
         longjmp(pframe->jmp,FASTRUBY_TAG_RETRY);"
        )
    end

    def to_c_redo(tree)
      if @on_block
         inline_block "
          longjmp(pframe->jmp,FASTRUBY_TAG_REDO);
          return Qnil;
          "
      else
          _raise("rb_eLocalJumpError","illegal redo");
      end
    end

    def to_c_next(tree)
      if @on_block
       inline_block "
        pframe->thread_data->accumulator = #{tree[1] ? to_c(tree[1]) : "Qnil"};
        longjmp(pframe->jmp,FASTRUBY_TAG_NEXT);
        return Qnil;
        "
      else
        _raise("rb_eLocalJumpError","illegal next");
      end
    end

    
  end
end
