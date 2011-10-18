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

    def convention(signature, inference_complete)
        recvtype = @owner
        if recvtype.respond_to? :fastruby_method and inference_complete

          method_tree = nil
          begin
            method_tree = recvtype.instance_method(@method_name.to_sym).fastruby.tree
          rescue NoMethodError, NameError
          end

          if method_tree
            
            args_tree = method_tree[2]
            
            if args_tree.any?{|x|x.to_s.match(/\*/)}
              :fastruby_array
            else
              :fastruby
            end
          else
            :cruby
          end
        else
          :cruby
        end
    end

    def build(signature, noreturn = false)
      return nil unless tree
      
      no_cache = false

      mname = FastRuby.make_str_signature(@method_name, signature)

      if @owner.respond_to? :method_hash
        method_hash = @owner.method_hash || {}
        if (method_hash[mname.to_sym.__id__])
          FastRuby.logger.info "NOT Building #{@owner}::#{@method_name} for signature #{signature.inspect}, it's already done"
          return @owner.instance_method(mname)
        end
      end
      
      require "fastruby/translator/translator"
      require "rubygems"
      require "inline"

      context = FastRuby::Context.new
      context.locals = locals
      context.options = options

      args_tree = tree[2]

      # create random method name
      context.snippet_hash = snippet_hash
      context.alt_method_name = "_" + @method_name.to_s + "_" + rand(10000000000).to_s

      (1..signature.size).each do |i|
        arg = args_tree[i]
        if arg
          context.infer_lvar_map[arg.to_s.gsub("*","").to_sym] = signature[i]
        end
      end

      context.infer_self = signature[0]
      c_code = context.to_c_method(tree,signature)

      unless options[:main]
         context.define_method_at_init(@owner,@method_name, args_tree.size+1, signature)
      end

      so_name = nil

      old_class_self = $class_self
      $class_self = @owner
      $last_obj_proc = nil

      begin

        @owner.class_eval do
          inline :C  do |builder|
            builder.inc << context.extra_code
            builder.include "<node.h>"
            builder.init_extra = context.init_extra

              def builder.generate_ext
                ext = []

                if @include_ruby_first
                  @inc.unshift "#include \"ruby.h\""
                else
                  @inc.push "#include \"ruby.h\""
                end

                ext << @inc
                ext << nil
                ext << @src.join("\n\n")
                ext << nil
                ext << nil
                ext << "#ifdef __cplusplus"
                ext << "extern \"C\" {"
                ext << "#endif"
                ext << "  void Init_#{module_name}() {"

                ext << @init_extra.join("\n") unless @init_extra.empty?

                ext << nil
                ext << "  }"
                ext << "#ifdef __cplusplus"
                ext << "}"
                ext << "#endif"
                ext << nil

                ext.join "\n"
              end

            builder.c c_code
            so_name = builder.so_name
          end
        end

        if $last_obj_proc
          unless options[:no_cache]
            FastRuby.cache.register_proc(so_name, $last_obj_proc)
          end
          $last_obj_proc.call($class_self)
        end

      ensure
        $class_self = old_class_self
      end

      unless no_cache
        no_cache = context.no_cache
      end

      unless options[:no_cache]
        FastRuby.cache.insert(snippet_hash, so_name) unless no_cache
      end

      ret = Object.new

      ret.extend MethodExtent
      ret.yield_signature = context.yield_signature

      ret

    end

    module MethodExtent
      attr_accessor :yield_signature
    end
  end

  module BuilderModule
    def build(signature, method_name, noreturn = false)
      fastruby_method(method_name.to_sym).build(signature, noreturn)
    end

    def convention(signature, method_name, inference_complete)
      fastruby_method(method_name.to_sym).convention(signature, inference_complete)
    end

    def register_method_value(key,value)
      @method_hash = Hash.new unless @method_hash
      @method_hash[key] = value
    end
    
    def method_hash
      @method_hash
    end
    
    def clear_method_hash
      @method_hash.clear if @method_hash
    end

    def fastruby_method(mname_)
      mname = mname_.to_sym
      @fastruby_method = Hash.new unless @fastruby_method
      @fastruby_method[mname] = FastRuby::Method.new(mname,self) unless @fastruby_method[mname]
      @fastruby_method[mname]
    end
  end
end
