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
  module BlockTranslator
    register_translator_module self
    
    def to_c_class(tree)
      str_class_name = get_class_name(tree[1])
      container_tree = get_container_tree(tree[1])

      if container_tree == s(:self)
        method_group("
                    VALUE tmpklass = rb_define_class(
                      #{str_class_name.inspect},
                      #{tree[2] ? to_c(tree[2]) : "rb_cObject"}
                  );
        ", tree[3])
      else
        method_group("
                    VALUE container_klass = #{to_c(container_tree)};
                    VALUE tmpklass = rb_define_class_under(
                      container_klass,
                      #{str_class_name.inspect},
                      #{tree[2] ? to_c(tree[2]) : "rb_cObject"}
                  );
        ", tree[3])
      end
    end

    def to_c_module(tree)
      str_class_name = get_class_name(tree[1])
      container_tree = get_container_tree(tree[1])

      if container_tree == s(:self)
        method_group("
                      VALUE tmpklass = rb_define_module(#{str_class_name.inspect});
        ", tree[2])
      else
        method_group("
                      VALUE container_klass = #{to_c(container_tree)};
                      VALUE tmpklass = rb_define_module_under(container_klass,#{str_class_name.inspect});
        ", tree[2])
      end
    end
  end
end
