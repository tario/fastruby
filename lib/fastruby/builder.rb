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
require "fastruby/method_extension"
require "fastruby/logging"
require "fastruby/getlocals"
require "fastruby_load_path"
require "fastruby/inliner/inliner"
require "fastruby/translator/translator"
require "rubygems"
require "inline"
require "fastruby/inline_extension"

require FastRuby.fastruby_load_path + "/../ext/fastruby_base/fastruby_base"

module FastRuby
  class Method
    attr_accessor :locals
    attr_accessor :options
    attr_accessor :snippet_hash

    def initialize(method_name, owner)
      @method_name = method_name
      @owner = owner
      @observers = Hash.new
    end
    
    def observe(key, &blk)
      @observers[key] = blk
    end
    
    def tree_changed
      @observers.values.each do |observer|
        observer.call(self)
      end
    end

    def build(signature, noreturn = false)
      return nil unless tree

      no_cache = false
      mname = FastRuby.make_str_signature(@method_name, signature)

      if @owner.respond_to? :method_hash
        method_hash = @owner.method_hash(@method_name.to_sym) || {}
        if (@owner.has_fastruby_function(method_hash,mname.to_s))
          FastRuby.logger.info "NOT Building #{@owner}::#{@method_name} for signature #{signature.inspect}, it's already done"
          return nil
        end
      end

      rebuild(signature, noreturn)
    end
    
    def rebuild(signature, noreturn = false)
      no_cache = false
      mname = FastRuby.make_str_signature(@method_name, signature)

      inliner = FastRuby::Inliner.new

      context = FastRuby::Context.new
      context.options = options

      args_tree = if tree[0] == :defn
         tree[2]
      elsif tree[0] == :defs
         tree[3]
      else
        raise ArgumentError, "unknown type of method definition #{tree[0]}"
      end

      # create random method name
      context.snippet_hash = snippet_hash
      context.alt_method_name = "_" + @method_name.to_s + "_" + rand(10000000000).to_s

      (1..signature.size-1).each do |i|
        arg = args_tree[i]
        
        if arg.instance_of? Symbol
          
          if arg
            if arg.to_s.match(/\*/)
              context.infer_lvar_map[arg.to_s.gsub("*","").to_sym] = Array
            else
              context.infer_lvar_map[arg.to_sym] = signature[i]
            end
          end
        end
      end

      context.infer_self = signature[0]
      
      inliner.infer_self = context.infer_self
      inliner.infer_lvar_map = context.infer_lvar_map

      inlined_tree = inliner.inline(tree)
      
      inliner.extra_inferences.each do |local, itype|
        context.infer_lvar_map[local] = itype
      end
      
      inliner.inlined_methods.each do |inlined_method|
        inlined_method.observe("#{@owner}##{@method_name}#{mname}") do |imethod|
          rebuild(signature, noreturn)
        end
      end
      
      alt_options = options.dup
      alt_options.delete(:self)
      
      #require "pry"; binding.pry
      code_sha1 = FastRuby.cache.hash_snippet(inlined_tree.inspect, FastRuby::VERSION + signature.map(&:to_s).join('-') + alt_options.inspect)
      
      paths = FastRuby.cache.retrieve(code_sha1)

      $last_obj_proc = nil
      if paths.empty?
        FastRuby.logger.info "Compiling #{@owner}::#{@method_name} for signature #{signature.inspect}"
        c_code = context.to_c_method(inlined_tree,signature)
   
        unless options[:main]
           context.define_method_at_init(@method_name, args_tree.size+1, signature)
        end
  
        so_name = nil
  
        old_class_self = $class_self
        $class_self = @owner
  
        begin

          unless $inline_extra_flags
            $inline_extra_flags = true
            
            ['CFLAGS','CXXFLAGS','OPTFLAGS','cflags','cxxflags','optflags'].each do |name|
              RbConfig::CONFIG[name].gsub!(/\-O\d/,"-O1") if RbConfig::CONFIG[name]
            end
            
            if RUBY_VERSION =~ /^1\.8/
              RbConfig::CONFIG['CFLAGS'] << " -DRUBY_1_8 -Wno-clobbered"
            elsif RUBY_VERSION =~ /^1\.9/
              RbConfig::CONFIG['CFLAGS'] << " -DRUBY_1_9 -Wno-clobbered"
            end
          end
          
          @owner.class_eval do
            inline :C  do |builder|
              builder.inc << context.extra_code
              builder.init_extra = context.init_extra
  
                def builder.generate_ext
                  ext = []
  
                  @inc.unshift "#include \"ruby.h\""
  
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
        
          unless no_cache
            no_cache = context.no_cache
          end
    
          unless no_cache
            FastRuby.cache.insert(code_sha1, so_name)
          end
        ensure
          $class_self = old_class_self
        end
      else
        paths.each do |path|
          require path
        end
      end

      if $last_obj_proc
        FastRuby.cache.register_proc(code_sha1, $last_obj_proc)
      end
      
      $class_self = @owner
      begin
        FastRuby.cache.execute(code_sha1, signature, @owner)
      ensure
        $class_self = old_class_self
      end
      
      observe("#{@owner}##{@method_name}#{mname}") do |imethod|
        if tree
          rebuild(signature, noreturn)
        end
      end
    end
  end

  module BuilderModule
    def build(signature, method_name, noreturn = false)
      fastruby_method(method_name.to_sym).build(signature, noreturn)
    end

    def register_method_value(method_name,key,value)
      @method_hash = Hash.new unless @method_hash
      @method_hash[method_name] = Hash.new unless @method_hash[method_name]
      @method_hash[method_name][key] = value
    end
    
    def method_hash(method_name)
      @method_hash = Hash.new unless @method_hash
      @method_hash[method_name]
    end
    
    def method_added(method_name)
      FastRuby.unset_tree(self,method_name)
    end

    def fastruby_method(mname_)
      mname = mname_.to_sym
      @fastruby_method = Hash.new unless @fastruby_method
      @fastruby_method[mname] = FastRuby::Method.new(mname,self) unless @fastruby_method[mname]
      @fastruby_method[mname]
    end
  end
end
