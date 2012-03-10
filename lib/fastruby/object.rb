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
require "fastruby/builder"
require "fastruby/getlocals"
require "fastruby/method_extension"
require "fastruby/cache/cache"
require "fastruby"
require "digest"
require "method_source"

# clean rubyinline cache
system("rm -fr #{ENV["HOME"]}/.ruby_inline/*")

$top_level_binding = binding

def lvar_type(*x); end

class Class
  def optimize(method_name)
    fastruby instance_method(method_name).source  
  end
end

module FastRuby
  def self.encapsulate_tree(tree, method_name)
      generated_tree = tree

      if generated_tree[0] == :scope
        generated_tree = s(:defn, method_name.to_sym, s(:args),
                s(:scope, s(:block, generated_tree[1])))
      elsif generated_tree[0] == :block
        generated_tree = s(:defn, method_name.to_sym, s(:args),
                    s(:scope, generated_tree))
      else
        generated_tree = s(:defn, method_name.to_sym, s(:args),
                    s(:scope, s(:block, generated_tree)))
      end

      generated_tree.to_fastruby_sexp
  end
end

class Object
  def fastruby?
    false
  end
end

class Object
  
  def infer(a); self; end
  def fastruby(*arguments, &blk)
    if blk
      method_container = Class.new
      class << method_container 
        attr_accessor :_self
        attr_accessor :fastruby_options
      end
      
      method_container._self = self
      method_container.fastruby_options = arguments.inject({},&:merge)
      
      def method_container.method_added(mname)
        m = instance_method(mname)
        if fastruby_options[:fastruby_only]
          tree = FastRuby::FastRubySexp.parse m.source
          FastRuby.set_tree(_self, tree[1], tree, fastruby_options)
        else
          @_self.fastruby m.source, fastruby_options
        end
      end
            
      method_container.class_eval(&blk)

      return nil
    end
    
    options_hashes = arguments[1..-1]
    argument = arguments.first
    
    options_hash = {:validate_lvar_types => true}
    options_hashes.each do |opt|
      options_hash.merge!(opt)
    end
    
      tree = nil

      require "fastruby/fastruby_sexp"
      if argument.instance_of? FastRuby::FastRubySexp
        tree = argument
      elsif argument.instance_of? String
        require "rubygems"
        require "ruby_parser"
        require "fastruby/sexp_extension"
        tree = RubyParser.new.parse(argument).to_fastruby_sexp
      else
        raise ArgumentError
      end

      return unless tree
        method_name = "_anonymous_" + Digest::SHA1.hexdigest(tree.inspect)
        Object.execute_tree(FastRuby.encapsulate_tree(tree,method_name), {:main => method_name, :self => self}.merge(options_hash))


  end

  def self.execute_tree(tree,*options_hashes)
    options_hash = {:validate_lvar_types => true}
    options_hashes.each do |opt|
      options_hash.merge!(opt)
    end

    require "fastruby/fastruby_sexp"
    method_name = tree[1]

    self_ = options_hash[:self]
    self_ = self unless self_.instance_of? Class

    FastRuby.set_tree(self_, method_name, tree, options_hash)

    class << self
      $metaclass = self
    end

    self_.build([$class_self],method_name,true)
  end

  def gc_register_object
    $refered_from_code_array = Array.new unless $refered_from_code_array
    $refered_from_code_array << self
  end
end

