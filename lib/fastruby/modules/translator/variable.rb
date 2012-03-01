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
  class Context
    define_translator_for(:cvar, :method => :to_c_cvar, :arity => 1)
    def to_c_cvar(tree)
      "rb_cvar_get(CLASS_OF(plocals->self) != rb_cClass ? CLASS_OF(plocals->self) : plocals->self,#{intern_num tree[1]})"
    end

    define_translator_for(:cvasgn, :method => :to_c_cvasgn)
    def to_c_cvasgn(tree, result_var = nil)
      if result_var
        "
          {
            VALUE recv = CLASS_OF(plocals->self) != rb_cClass ? CLASS_OF(plocals->self) : plocals->self;

            #{to_c tree[2], result_var};
            
            #{if RUBY_VERSION =~ /^1\.9/
              "rb_cvar_set(recv,#{intern_num tree[1]},#{result_var});"
              elsif RUBY_VERSION =~ /^1\.8/
              "rb_cvar_set(recv,#{intern_num tree[1]},#{result_var},Qfalse);"
              else
                raise RuntimeError, "unsupported ruby version #{RUBY_VERSION}"
              end 
            }
          }
       "
      else
      "__rb_cvar_set(CLASS_OF(plocals->self) != rb_cClass ? CLASS_OF(plocals->self) : plocals->self,#{intern_num tree[1]},#{to_c tree[2]},Qfalse)"
      end
    end

    define_translator_for(:gvar, :method => :to_c_gvar, :arity => 1)
    def to_c_gvar(tree)
      if (tree[1] == :$!)
        "pframe->thread_data->exception"
      else
        "rb_gvar_get((struct global_entry*)#{global_entry(tree[1])})"
      end
    end

    define_translator_for(:gasgn, :method => :to_c_gasgn)
    def to_c_gasgn(tree, result_var = nil)
      if result_var
          "
          {
          #{to_c tree[2], result_var}; 
          rb_gvar_set((void*)#{global_entry(tree[1])},#{result_var});
          }
          "
      else
      "_rb_gvar_set((void*)#{global_entry(tree[1])}, #{to_c tree[2]})"
      end
    end

    define_translator_for(:ivar, :method => :to_c_ivar, :arity => 1)
    def to_c_ivar(tree)
      "rb_ivar_get(#{locals_accessor}self,#{intern_num tree[1]})"
    end

    define_translator_for(:iasgn, :method => :to_c_iasgn)
    def to_c_iasgn(tree, result_var = nil)
      if result_var
          "
          {
          #{to_c tree[2], result_var}; 
          rb_ivar_set(#{locals_accessor}self,#{intern_num tree[1]},#{result_var});
          }
          "
      else
        "_rb_ivar_set(#{locals_accessor}self,#{intern_num tree[1]},#{to_c tree[2]})"
      end
    end

    define_translator_for(:const, :arity => 1) do |tree|
      "rb_const_get(CLASS_OF(plocals->self), #{intern_num(tree[1])})"
    end
    
    define_translator_for(:cdecl, :method => :to_c_cdecl)
    def to_c_cdecl(tree, result_var_ = nil)
      
      result_var = result_var_ || "value"
      
      if tree[1].instance_of? Symbol
        code = proc{"
          {
            // set constant #{tree[1].to_s}
            #{to_c tree[2], result_var};
            rb_const_set(rb_cObject, #{intern_num tree[1]}, #{result_var});
          }
          "}
      elsif tree[1].instance_of? FastRuby::FastRubySexp

        if tree[1].node_type == :colon2
          code = proc{"
            {
              // set constant #{tree[1].to_s}
              #{to_c tree[2], result_var};
              VALUE klass = Qnil;
              #{to_c tree[1][1], "klass"};
              rb_const_set(klass, #{intern_num tree[1][2]}, #{result_var});
            }
            "}
        elsif tree[1].node_type == :colon3
          code = proc{"
            {
            // set constant #{tree[1].to_s}
            #{to_c tree[2], result_var};
            rb_const_set(rb_cObject, #{intern_num tree[1][1]}, #{result_var});
            }
            "}
        end
      end

        if result_var_
          code.call
        else
           inline_block{"VALUE #{result_var} = Qnil;\n" + code.call + "
            return #{result_var};
           "}
        end
    end

    define_translator_for(:colon3, :method => :to_c_colon3, :arity => 1)
    def to_c_colon3(tree)
      "rb_const_get_from(rb_cObject, #{intern_num tree[1]})"
    end
   
    define_translator_for(:colon2, :method => :to_c_colon2) 
    def to_c_colon2(tree, result_var = nil)
      code = proc{ "
        {
        VALUE klass = Qnil;
        
        #{to_c tree[1],"klass"};
            #{
            if result_var
              "#{result_var} = Qnil;"
            end
          }

      if (rb_is_const_id(#{intern_num tree[2]})) {
        switch (TYPE(klass)) {
          case T_CLASS:
          case T_MODULE:
            #{
            if result_var
              "#{result_var} = rb_const_get_from(klass, #{intern_num tree[2]});"
            else
              "return rb_const_get_from(klass, #{intern_num tree[2]});"
            end
            }
            break;
          default:
            #{_raise("rb_eTypeError","not a class/module")};
            break;
        }
      }
      else {
            #{
            if result_var
              "#{result_var} = rb_funcall(klass, #{intern_num tree[2]}, 0, 0);"
            else
              "return rb_funcall(klass, #{intern_num tree[2]}, 0, 0);"
            end
            }
      }
        
            #{
            unless result_var
              "return Qnil;"
            end
            }
        }
      "}
      
      if result_var
        code.call
      else
        inline_block &code
      end
    end

    define_translator_for(:lasgn, :method => :to_c_lasgn)
    def to_c_lasgn(tree, result_var = nil)
      code = "
          {
            #{to_c tree[2], result_var};
            #{locals_accessor}#{tree[1]} = #{result_var};
           }
           "

      if result_var
        if options[:validate_lvar_types]
          klass = @infer_lvar_map[tree[1]]
          if klass
            "
            {
              #{to_c tree[2], result_var};
              if (CLASS_OF(#{result_var})!=#{literal_value klass}) {
                #{_raise(literal_value(FastRuby::TypeMismatchAssignmentException), "Illegal assignment at runtime (type mismatch)")};
              }
              #{locals_accessor}#{tree[1]} = #{result_var};
            }
           "
          else
            code
          end
        else
          code
        end
      else
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
    end
    
    define_translator_for(:lvar, :arity => 1) do |tree|
      locals_accessor + tree[1].to_s
    end

    define_translator_for(:defined, :method => :to_c_defined, :arity => 1)
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
        if RUBY_VERSION =~ /^1\.8/
        "rb_method_node(CLASS_OF(#{to_c tree[1][1]}), #{intern_num tree[1][2]}) ? #{literal_value "method"} : Qnil"
        else
        "rb_method_entry(CLASS_OF(#{to_c tree[1][1]}), #{intern_num tree[1][2]}) ? #{literal_value "method"} : Qnil"
        end
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
