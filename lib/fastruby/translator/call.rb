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
  module CallTranslator
    
    register_translator_module self

    def to_c_call(tree, repass_var = nil)
      directive_code = directive(tree)
      if directive_code
        return directive_code
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

      mname = :require_fastruby if mname == :require

      strargs = args[1..-1].map{|arg| to_c arg}.join(",")

      argnum = args.size - 1

      recv = recv || s(:self)

      recvtype = infer_type(recv)

      if recvtype

        address = nil
        mobject = nil

        inference_complete = true
        signature = [recvtype]

        args[1..-1].each do |arg|
          argtype = infer_type(arg)
          if argtype
            signature << argtype
          else
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

          if argnum == 0
            value_cast = "VALUE,VALUE,VALUE"
            "((VALUE(*)(#{value_cast}))#{encode_address(recvtype,signature,mname,tree,inference_complete)})(#{to_c recv}, Qfalse, (VALUE)pframe)"
          else
            value_cast = ( ["VALUE"]*(args.size) ).join(",") + ",VALUE,VALUE"
            "((VALUE(*)(#{value_cast}))#{encode_address(recvtype,signature,mname,tree,inference_complete)})(#{to_c recv}, Qfalse, (VALUE)pframe, #{strargs})"
          end

      else # else recvtype
        if argnum == 0
          protected_block("rb_funcall(#{to_c recv}, #{intern_num tree[2]}, 0)", true, repass_var)
        else
          protected_block("rb_funcall(#{to_c recv}, #{intern_num tree[2]}, #{argnum}, #{strargs} )", true, repass_var)
        end
      end # if recvtype
    end

    def to_c_attrasgn(tree)
      to_c_call(tree)
    end
  end
end
