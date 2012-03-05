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
    define_translator_for(:iter, :arity => 1, :priority => 1) { |*x|
      ret = nil
      tree = x.first
      
      enable_handler_group(:static_call) do
        ret = x.size == 1 ? to_c(tree[3]) : to_c(tree[3], x.last)
      end
      ret
    }.condition{ |*x|
      tree = x.first
      tree.node_type == :iter && tree[1][2] == :_static
    }
    
    define_translator_for(:iter, :arity => 1, :priority => 1) { |*x|
      ret = nil
      tree = x.first
      
      disable_handler_group(:static_call) do
        ret = x.size == 1 ? to_c(tree[3]) : to_c(tree[3], x.last)
      end
      ret
    }.condition{ |*x|
      tree = x.first
      tree.node_type == :iter && tree[1][2] == :_dynamic
    }
    
    handler_scope(:group => :static_call, :priority => 1000) do
      define_translator_for(:call) do |tree, result=nil|
        method_name = tree[2].to_s
        recv_tree = tree[1]
        
        if recv_tree and recv_tree.node_type != :self
          if (not tree[2].to_s =~ /^[a-zA-Z]/) and tree[2].to_s.size <= 3
            c_op = tree[2].to_s
            c_op = '==' if tree[2] == :===
            code = "( ( #{to_c(tree[1])} )#{c_op}(#{to_c(tree[3][1])}) )"
          elsif tree[2] == :_invariant
            name = self.add_global_name("VALUE", "Qnil");
            
            init_extra << "
                #{name} = #{to_c tree[1]};
                rb_funcall(#{name},#{intern_num :gc_register_object},0);
              "
              
            code = name;
          else
            raise "invalid static call #{method_name} with recv"
          end
        else
          args = tree[3][1..-1].map(&method(:to_c)).join(",")
          code = "#{method_name}( #{args} )"
        end

        if result
          "#{result} = #{code};"
        else
          code
        end
      end
      
      define_translator_for(:lit) do |tree, result=nil|
        if result
          "#{result} = #{tree[1]};"
        else
          tree[1].to_s
        end
      end
      
      define_translator_for(:if) do |tree, result_variable_ = nil|
        condition_tree = tree[1]
        impl_tree = tree[2]
        else_tree = tree[3]
        
        result_variable = result_variable_ || "last_expression"
        
        code = proc {"
          {
            VALUE condition_result;
            #{to_c condition_tree, "condition_result"};
            if (condition_result) {
              #{to_c impl_tree, result_variable};
            }#{else_tree ?
              " else {
              #{to_c else_tree, result_variable};
              }
              " : ""
            }
          }
        "}
  
        if result_variable_
          code.call
        else
          inline_block(&code) + "; return last_expression;"
        end      
      end
      
      define_translator_for(:while) do |tree, result_var = nil|
        begin_while = "begin_while_"+rand(10000000).to_s
        end_while = "end_while_"+rand(10000000).to_s
        aux_varname = "_aux_" + rand(10000000).to_s
        code = proc {"
          {
            VALUE while_condition;
            VALUE #{aux_varname};
            
  #{begin_while}:
            #{to_c tree[1], "while_condition"};
            if (!(while_condition)) goto #{end_while}; 
            #{to_c tree[2], aux_varname};
            goto #{begin_while};
  #{end_while}:
            
            #{
            if result_var
              "#{result_var} = Qnil;"
            else
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
           
      define_translator_for(:and) do |tree, return_var = nil|
        if return_var
          "
            {
              VALUE op1 = Qnil;
              VALUE op2 = Qnil;
              #{to_c tree[1], "op1"};
              #{to_c tree[2], "op2"};
              #{return_var} = ((op1) &&(op2));
            }
          "
        else
          "((#{to_c tree[1]}) && (#{to_c tree[2]}))"
        end
        
      end
      
      define_translator_for(:or) do |tree, return_var = nil|
        if return_var
          "
            {
              VALUE op1 = Qnil;
              VALUE op2 = Qnil;
              #{to_c tree[1], "op1"};
              #{to_c tree[2], "op2"};
              #{return_var} = ((op1) ||(op2));
            }
          "
        else
          "((#{to_c tree[1]}) || (#{to_c tree[2]}))"
        end
        
      end
      
      define_translator_for(:not) do |tree, return_var = nil|
        if return_var
          "
            {
              VALUE op1 = Qnil;
              #{to_c tree[1], "op1"};
              #{return_var} = ((op1) ? 0: 1);
            }
          "
        else
          "((#{to_c tree[1]}) ? 0 : 1)"
        end
      end
          
    end

    define_method_handler(:initialize_to_c){|*x|}.condition do |*x|
      disable_handler_group(:static_call, :to_c); false
    end
    

    define_method_handler(:infer_value) { |tree|
      Value.new(eval(tree[1].to_s))
    }.condition{|tree| tree.node_type == :const}
    
    define_method_handler(:infer_value) { |tree|
      args_tree = tree[3]
      receiver_tree = tree[1]
      
      value_1 = infer_value(receiver_tree)
      value_2 = infer_value(args_tree[1])

      next false unless (value_1 and value_2)
      
      Value.new(value_1.value == value_2.value)
    }.condition{|tree|
      next false unless tree.node_type == :call
      
      args_tree = tree[3]
      method_name = tree[2]
       
      next false unless method_name == :==
      next false if args_tree.size < 2

      true
    }
    define_method_handler(:infer_value) { |tree|
      args_tree = tree[3]
      receiver_tree = tree[1]
      infered_type = infer_type(receiver_tree)

      if infered_type
        Value.new(infered_type)
      else
        nil
      end
    }.condition{|tree|
      next false unless tree.node_type == :call
      method_name = tree[2]
      next false unless method_name == :_class
      true
    }
  end
end
