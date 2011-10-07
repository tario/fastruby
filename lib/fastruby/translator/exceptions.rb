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
require "fastruby/method_extension"
require "fastruby/set_tree"
require "fastruby/exceptions"
require "fastruby/translator/translator_modules"
require "rubygems"
require "sexp"

module FastRuby
  module ExceptionsTranslator
    register_translator_module self


    def to_c_rescue(tree)
      if tree[1][0] == :resbody
        else_tree = tree[2]

        if else_tree
          to_c else_tree
        else
          "Qnil"
        end
      else
        resbody_tree = tree[2]
        else_tree = nil
        if tree[-1]
          if tree[-1][0] != :resbody
            else_tree = tree[-1]
          end
        end

        catch_condition_array = []
        lasgn_code = ""
        resbody_code = to_c(resbody_tree[2])

        rescue_code = ""

        tree[1..-1].each do |resbody_tree|
          next if resbody_tree[0] != :resbody

          if resbody_tree[1].size == 1
            resbody_tree[1][1] = [:const, :Exception]
          end

          if resbody_tree[1].last[0] == :lasgn
            lasgn_code = to_c(resbody_tree[1].last)
          end

          resbody_tree[1][1..-1].each do |xtree|
            if xtree[0] != :lasgn
              trapcode = "rb_eException";

              if xtree
                trapcode = to_c(xtree)
              end

              catch_condition_array << "(rb_obj_is_kind_of(frame.thread_data->exception,#{trapcode}) == Qtrue)"
            end
          end

          rescue_code << "
            if (aux == FASTRUBY_TAG_RAISE) {
              if (#{catch_condition_array.join(" || ")})
              {
                // trap exception
                frame.targetted = 1;

                #{lasgn_code};

                 #{resbody_code};
              }
            }
          "
        end

        frame_call(
          frame(to_c(tree[1])+";","
            #{rescue_code}
          ", else_tree ? to_c(else_tree) : nil, 1)

          )
      end
    end

    def to_c_ensure(tree)
      if tree.size == 2
        to_c tree[1]
      else
        ensured_code = to_c tree[2]
        inline_block "
          #{frame(to_c(tree[1]),ensured_code,ensured_code,1)};
        "
      end
    end

    def _raise(class_tree, message_tree = nil)
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
    
  end
end
