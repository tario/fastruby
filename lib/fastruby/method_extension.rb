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
  module MethodExtension
    def fastruby
      owner.fastruby_method(name.to_sym)
    end

    def self.build_method_helpers
      inline :C  do |builder|
        builder.include "<node.h>"
        builder.c "VALUE getaddress_() {
            struct METHOD {
              VALUE klass, rklass;
              VALUE recv;
              ID id, oid;
              int safe_level;
              NODE *body;
            };

            struct METHOD *data;
            Data_Get_Struct(self, struct METHOD, data);

            if (nd_type(data->body) == NODE_CFUNC) {
              return INT2FIX(data->body->nd_cfnc);
            }

            return 0;
        }"

        builder.c "VALUE getlen_() {
            struct METHOD {
              VALUE klass, rklass;
              VALUE recv;
              ID id, oid;
              int safe_level;
              NODE *body;
            };

            struct METHOD *data;
            Data_Get_Struct(self, struct METHOD, data);

            if (nd_type(data->body) == NODE_CFUNC) {
              return INT2FIX(data->body->nd_argc);
            }

            return Qnil;
        }"
      end

      alias getaddress getaddress_
      alias getlen getlen_
    end

    @@helper_compiled = false

    def getaddress
      unless @@helper_compiled
        FastRuby::MethodExtension.build_method_helpers
        @@helper_compiled = true
      end

      getaddress_
    end

    def getlen
      unless @@helper_compiled
        FastRuby::MethodExtension.build_method_helpers
        @@helper_compiled = true
      end

      getlen_
    end

  end
end

class Method
  include FastRuby::MethodExtension
end

class UnboundMethod
  include FastRuby::MethodExtension
end
