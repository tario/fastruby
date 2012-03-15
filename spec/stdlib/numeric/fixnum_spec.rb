require "fastruby"

describe FastRuby, "fastruby fixnum stdlib" do
  
  $fixnum_class_num = 0
  def self.test_op_with_type(recv, op, parameter, expected = recv.send(op, parameter))
    _classname = "FXNUMTEST#{$fixnum_class_num}"
    
    it "receiver #{recv}.#{op}(#{parameter}) should return #{expected} #{expected.class}" do
    fastruby(
      "class #{_classname}
          def foo(parameter)
            #{recv}.#{op}(parameter)
          end
        end
      "
    
    )
    
      eval(_classname).new.foo(parameter).should be == expected
    end
    
    $fixnum_class_num = $fixnum_class_num + 1
  end

  def self.test_op(recv, op, parameter, expected = recv.send(op, parameter))
    _classname = "FXNUMTEST#{$fixnum_class_num}"
    
    it "receiver #{recv}.#{op}(#{parameter}) should return #{expected} #{expected.class}" do
    fastruby(
      "class #{_classname}
          def foo(parameter)
            #{recv}.#{op}(parameter.call)
          end
        end
      "
    
    )
    
      eval(_classname).new.foo( lambda{parameter} ).should be == expected
    end
    
    $fixnum_class_num = $fixnum_class_num + 1
  end
  
  def self.test_unary_op(recv, op, expected = recv.send(op))
    _classname = "FXNUMTEST#{$fixnum_class_num}"
    
    it "receiver #{recv}.#{op} should return #{expected} #{expected.class}" do
    fastruby(
      "class #{_classname}
          def foo
            #{recv}.#{op}
          end
        end
      "
    
    )
    
      eval(_classname).new.foo.should be == expected
    end
    $fixnum_class_num = $fixnum_class_num + 1
  end

  
  class CustomValue
    def method_missing(m,x)
      42
    end    
    def <(x)
      true
    end

    def >(x)
      false
    end
    
    def coerce(other)
      return self, other
    end
  end
  
  [:-@, :abs, :magnitude, :to_f, :size, :zero?, :odd?, :even?, :succ].each do |op|
    test_unary_op(31,op)
    test_unary_op(-31,op)
  end
  
  #TODO: upto, downto, succ, next, pred, chr

  [:+, :-, :<, :>, :/,:div,:%,:modulo,:divmod,:fdiv,:**,:==,:===,:<=>,:>=,:<=].each do |op|
    [1,1.1,10**10,CustomValue.new].each do |value|
      test_op_with_type(1,op,value)
      test_op(1,op,value)
    end
  end

  [:&,:|,:^,:[],:<<,:>>].each do |op|
    [1,2,3].each do |value|
      test_op_with_type(1,op,value)
      test_op(1,op,value)
    end
  end

end
