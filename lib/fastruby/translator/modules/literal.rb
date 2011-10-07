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
  module LiteralTranslator
    register_translator_module self

    def to_c_lit(tree)
      literal_value tree[1]
    end

    def to_c_nil(tree)
      "Qnil"
    end

    def to_c_str(tree)
      literal_value tree[1]
    end

    def to_c_hash(tree)

      hash_aset_code = ""
      (0..(tree.size-3)/2).each do |i|
        strkey = to_c tree[1 + i * 2]
        strvalue = to_c tree[2 + i * 2]
        hash_aset_code << "rb_hash_aset(hash, #{strkey}, #{strvalue});"
      end

      anonymous_function{ |name| "
        static VALUE #{name}(VALUE value_params) {
          #{@frame_struct} *pframe;
          #{@locals_struct} *plocals;
          pframe = (void*)value_params;
          plocals = (void*)pframe->plocals;

          VALUE hash = rb_hash_new();
          #{hash_aset_code}
          return hash;
        }
      " } + "((VALUE)pframe)"
    end

    def to_c_array(tree)
      if tree.size > 1
        strargs = tree[1..-1].map{|subtree| to_c subtree}.join(",")
        "rb_ary_new3(#{tree.size-1}, #{strargs})"
      else
        "rb_ary_new3(0)"
      end
    end

    def to_c_self(tree)
      locals_accessor + "self"
    end

    def to_c_false(tree)
      "Qfalse"
    end

    def to_c_true(tree)
      "Qtrue"
    end

    def to_c_dot2(tree)
      "rb_range_new(#{to_c tree[1]}, #{to_c tree[2]},0)"
    end
    
  end
end
