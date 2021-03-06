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

module FastRuby

  def self.make_str_signature(method_name, signature)
    "_" + method_name.to_s + signature.map(&:__id__).map(&:to_s).join
  end

  def self.set_builder_module(klass)
    klass.class_eval do
      class << self
        include FastRuby::BuilderModule
      end
    end
  end
  
  def self.unset_tree(klass, method_name)
    fastrubym = klass.fastruby_method(method_name)
    fastrubym.tree = nil
    fastrubym.tree_changed
    nil
  end

  def self.set_tree(klass, method_name, tree, options = {})
    unless options[:skip_reduce]
      unless defined? Reductor
        require "fastruby/builder/reductor"
      end
      
      tree = Reductor.new.reduce(tree)
    end

    klass.class_eval do
      class << self
        include FastRuby::BuilderModule
      end
    end

    fastrubym = klass.fastruby_method(method_name)
    
    fastrubym.tree = tree
    fastrubym.options = options
    fastrubym.tree_changed

    nil
  end
end
