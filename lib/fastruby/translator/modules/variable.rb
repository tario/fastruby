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
  module VariabeTranslator
    register_translator_module self


    def to_c_cvar(tree)
      "rb_cvar_get(CLASS_OF(plocals->self) != rb_cClass ? CLASS_OF(plocals->self) : plocals->self,#{intern_num tree[1]})"
    end

    def to_c_cvasgn(tree)
      "__rb_cvar_set(CLASS_OF(plocals->self) != rb_cClass ? CLASS_OF(plocals->self) : plocals->self,#{intern_num tree[1]},#{to_c tree[2]},Qfalse)"
    end

    def to_c_gvar(tree)
      if (tree[1] == :$!)
        "pframe->thread_data->exception"
      else
        "rb_gvar_get((struct global_entry*)#{global_entry(tree[1])})"
      end
    end

    def to_c_gasgn(tree)
      "_rb_gvar_set((void*)#{global_entry(tree[1])}, #{to_c tree[2]})"
    end

    def to_c_ivar(tree)
      "rb_ivar_get(#{locals_accessor}self,#{intern_num tree[1]})"
    end

    def to_c_iasgn(tree)
      "_rb_ivar_set(#{locals_accessor}self,#{intern_num tree[1]},#{to_c tree[2]})"
    end

    def to_c_const(tree)
      "rb_const_get(CLASS_OF(plocals->self), #{intern_num(tree[1])})"
    end
    
    def to_c_cdecl(tree)
      if tree[1].instance_of? Symbol
        inline_block "
          // set constant #{tree[1].to_s}
          VALUE val = #{to_c tree[2]};
          rb_const_set(rb_cObject, #{intern_num tree[1]}, val);
          return val;
          "
      elsif tree[1].instance_of? FastRuby::FastRubySexp

        if tree[1].node_type == :colon2
          inline_block "
            // set constant #{tree[1].to_s}
            VALUE val = #{to_c tree[2]};
            VALUE klass = #{to_c tree[1][1]};
            rb_const_set(klass, #{intern_num tree[1][2]}, val);
            return val;
            "
        elsif tree[1].node_type == :colon3
          inline_block "
            // set constant #{tree[1].to_s}
            VALUE val = #{to_c tree[2]};
            rb_const_set(rb_cObject, #{intern_num tree[1][1]}, val);
            return val;
            "
        end
      end
    end

    def to_c_colon3(tree)
      "rb_const_get_from(rb_cObject, #{intern_num tree[1]})"
    end
    
    def to_c_colon2(tree)
      inline_block "
        VALUE klass = #{to_c tree[1]};

      if (rb_is_const_id(#{intern_num tree[2]})) {
        switch (TYPE(klass)) {
          case T_CLASS:
          case T_MODULE:
            return rb_const_get_from(klass, #{intern_num tree[2]});
            break;
          default:
            #{_raise("rb_eTypeError","not a class/module")};
            break;
        }
      }
      else {
        return rb_funcall(klass, #{intern_num tree[2]}, 0, 0);
      }

        return Qnil;
      "
    end

    def to_c_lasgn(tree)
      if options[:validate_lvar_types]
        klass = @infer_lvar_map[tree[1]]
        if klass

          verify_type_function = proc { |name| "
            static VALUE #{name}(VALUE arg, void* pframe ) {
              if (CLASS_OF(arg)!=#{literal_value klass}) {
                #{_raise(literal_value(FastRuby::TypeMismatchAssignmentException), "Illegal assignment at runtime (type mismatch)")};
              }
              return arg;
            }
          "
          }


          "_lvar_assing(&#{locals_accessor}#{tree[1]}, #{anonymous_function(&verify_type_function)}(#{to_c tree[2]},pframe))"
        else
          "_lvar_assing(&#{locals_accessor}#{tree[1]},#{to_c tree[2]})"
        end
      else
        "_lvar_assing(&#{locals_accessor}#{tree[1]},#{to_c tree[2]})"
      end
    end

    def to_c_lvar(tree)
      locals_accessor + tree[1].to_s
    end


    def to_c_defined(tree)
      nt = tree[1].node_type

      if nt == :self
      'rb_str_new2("self")'
      elsif nt == :true
      'rb_str_new2("true")'
      elsif nt == :false
      'rb_str_new2("false")'
      elsif nt == :nil
      'rb_str_new2("nil")'
      elsif nt == :lvar
      'rb_str_new2("local-variable")'
      elsif nt == :gvar
      "rb_gvar_defined((struct global_entry*)#{global_entry(tree[1][1])}) ? #{literal_value "global-variable"} : Qnil"
      elsif nt == :const
      "rb_const_defined(rb_cObject, #{intern_num tree[1][1]}) ? #{literal_value "constant"} : Qnil"
      elsif nt == :call
      "Qnil"
      elsif nt == :yield
        "rb_block_given_p() ? #{literal_value "yield"} : Qnil"
      elsif nt == :ivar
      "rb_ivar_defined(plocals->self,#{intern_num tree[1][1]}) ? #{literal_value "instance-variable"} : Qnil"
      elsif nt == :attrset or
            nt == :op_asgn1 or
            nt == :op_asgn2 or
            nt == :op_asgn_or or
            nt == :op_asgn_and or
            nt == :op_asgn_masgn or
            nt == :masgn or
            nt == :lasgn or
            nt == :dasgn or
            nt == :dasgn_curr or
            nt == :gasgn or
            nt == :iasgn or
            nt == :cdecl or
            nt == :cvdecl or
            nt == :cvasgn
        literal_value "assignment"
      else
        literal_value "expression"
      end
    end

    
  end
end
