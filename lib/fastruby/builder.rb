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
require "fastruby/inline_extension"
require "fastruby/method_extension"
require "fastruby/logging"
require "fastruby/getlocals"

module FastRuby

  def self.build_defs(tree, *options)
    method_name = tree[2].to_s

    FastRuby.logger.info "Building singleton method #{self}::#{@method_name}"

    locals = GetLocalsProcessor.get_locals(tree)
    locals << :self

    context = FastRuby::Context.new(false)
    context.locals = locals
    context.options = options

    context.alt_method_name = "singleton_" + method_name + rand(100000000).to_s

    [context.extra_code + context.to_c_method_defs(tree), context.alt_method_name, context.init_extra]
  end

  class Method
    attr_accessor :tree
    attr_accessor :locals
    attr_accessor :options
    attr_accessor :snippet_hash

    def initialize(method_name, owner)
      @method_name = method_name
      @owner = owner
    end

    def method_from_signature(signature, inference_complete)
        recvtype = @owner
        if recvtype.respond_to? :fastruby_method and inference_complete

          method_tree = nil
          begin
            method_tree = recvtype.instance_method(@method_name.to_sym).fastruby.tree
          rescue NoMethodError
          end

          if method_tree
            recvtype.build(signature, @method_name.to_sym)
          else
            recvtype.instance_method(@method_name.to_sym)
          end
        else
          recvtype.instance_method(@method_name.to_sym)
        end
    end

    def convention(signature, inference_complete)
        recvtype = @owner
        if recvtype.respond_to? :fastruby_method and inference_complete

          method_tree = nil
          begin
            method_tree = recvtype.instance_method(@method_name.to_sym).fastruby.tree
          rescue NoMethodError
          end

          if method_tree
            :fastruby
          else
            :cruby
          end
        else
          :cruby
        end
    end

    def build(signature)
      require "fastruby/translator"
      require "rubygems"
      require "inline"

      mname = FastRuby.make_str_signature(@method_name, signature)

      begin
        if (@owner.instance_method(mname))
          FastRuby.logger.info "NOT Building #{@owner}::#{@method_name} for signature #{signature.inspect}, it's already done"
          return @owner.instance_method(mname)
        end
      rescue NameError
        FastRuby.logger.info "Building #{@owner}::#{@method_name} for signature #{signature.inspect}"
      end

      context = FastRuby::Context.new
      context.locals = locals
      context.options = options

      args_tree = tree[2]

      # create random method name
      context.snippet_hash = snippet_hash
      context.alt_method_name = "_" + @method_name.to_s + "_" + rand(10000000000).to_s

      (1..signature.size).each do |i|
        arg = args_tree[i]
        context.infer_lvar_map[arg] = signature[i]
      end

      context.infer_self = signature[0]
      c_code = context.to_c_method(tree)

      begin
        context.define_method_at_init(@owner, @method_name, args_tree.size+1, signature)
      rescue TypeError => e
      end

      so_name = nil
      @owner.class_eval do
        inline :C  do |builder|
          builder.inc << context.extra_code
          builder.include "<node.h>"
          builder.init_extra = context.init_extra
          builder.c c_code
          so_name = builder.so_name
        end
      end
      FastRuby.cache.insert(snippet_hash, so_name)

      ret = @owner.instance_method(context.alt_method_name)

      ret.extend MethodExtent
      ret.yield_signature = context.yield_signature

      ret
    end

    module MethodExtent
      attr_accessor :yield_signature
    end
  end

  module BuilderModule
    def build(signature, method_name)
      fastruby_method(method_name.to_sym).build(signature)
    end

    def convention(signature, method_name, inference_complete)
      fastruby_method(method_name.to_sym).convention(signature, inference_complete)
    end

    def method_from_signature(signature, method_name, inference_complete)
      fastruby_method(method_name.to_sym).method_from_signature(signature, inference_complete)
    end

    def fastruby_method(mname_)
      mname = mname_.to_sym
      @fastruby_method = Hash.new unless @fastruby_method
      @fastruby_method[mname] = FastRuby::Method.new(mname,self) unless @fastruby_method[mname]
      @fastruby_method[mname]
    end
  end
end
