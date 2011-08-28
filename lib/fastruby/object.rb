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

# clean rubyinline cache
system("rm -fr #{ENV["HOME"]}/.ruby_inline/*")

$top_level_binding = binding

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
  def fastruby(argument, *options_hashes)
    options_hash = {:validate_lvar_types => true}
    options_hash[:no_cache] = true if ENV['FASTRUBY_NO_CACHE'] == "1"
    options_hashes.each do |opt|
      options_hash.merge!(opt)
    end

    objs = Array.new

    unless options_hash[:no_cache]
      snippet_hash = FastRuby.cache.hash_snippet(argument,options_hash[:validate_lvar_types].to_s + "^" + FastRuby::VERSION)
      objs = FastRuby.cache.retrieve(snippet_hash)
    end

    if objs.empty?

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
        method_name = "_anonymous_" + rand(100000000000).to_s
        Object.execute_tree(FastRuby.encapsulate_tree(tree,method_name), :main => method_name, :self => self, :snippet_hash => snippet_hash, *[options_hash])

    else

      objs.sort{|x,y|
          (y =~ /Inline_Object/ ? 1 : 0) - (x =~ /Inline_Object/ ? 1 : 0)
        }.each do |obj|

        begin
          $last_obj_proc = nil
          require obj
          if $last_obj_proc
            FastRuby.cache.register_proc(obj, $last_obj_proc)
          end
          FastRuby.cache.execute(obj, self)
        rescue
        end
      end
    end
  end

  def self.execute_tree(argument,*options_hashes)
    options_hash = {:validate_lvar_types => true}
    options_hashes.each do |opt|
      options_hash.merge!(opt)
    end

    require "fastruby/fastruby_sexp"
    if argument.instance_of? FastRuby::FastRubySexp
      tree = argument
    elsif argument.instance_of? String
      require "rubygems"
      require "ruby_parser"
      require "fastruby/sexp_extension"
      tree = RubyParser.new.parse(argument).to_fastruby_sexp
    else
      require "pry"
      binding.pry
      raise ArgumentError
    end

    method_name = tree[1]

    self_ = options_hash[:self]
    self_ = self unless self_.instance_of? Class

    FastRuby.set_tree(self_, method_name, tree, options_hash[:snippet_hash], options_hash)

    class << self
      $metaclass = self
    end

    self_.build([$class_self],method_name,true)
  end

  def gc_register_object
    $refered_from_code_array = Array.new unless $refered_from_code_array
    $refered_from_code_array << self
  end

  private
      def self.to_class_name(argument)
        require "sexp"
        if argument.instance_of? Symbol
          argument.to_s
        elsif argument.instance_of? Sexp
          if argument[0] == :colon3
            "::" + to_class_name(argument[1])
          elsif argument[0] == :colon2
            to_class_name(argument[1]) + "::" + to_class_name(argument[2])
          elsif argument[0] == :const
            to_class_name(argument[1])
          end
        end
      end

end

