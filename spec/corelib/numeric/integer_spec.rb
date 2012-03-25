require "fastruby"

describe FastRuby, "fastruby integer corelib" do
  
  $fixnum_class_num = 0
  def self.test_op(recv, op, parameter, expected = recv.send(op, parameter))
    _classname = "INTEGERNUMTEST#{$fixnum_class_num}"
    
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

  def self.test_op_block(recv, op, argument)
    _classname = "INTEGERNUMTEST#{$fixnum_class_num}"
    
    expected = Array.new
    recv.send(op, argument, &expected.method(:<<))
    
    it "receiver #{recv}.#{op} should return #{expected} #{expected.class}" do
    fastruby(
      "class #{_classname}
          def foo(argument, &blk)
            #{recv}.#{op}(argument.call, &blk)
          end
        end
      "
    
    )
    
      returned = Array.new
      eval(_classname).new.foo(lambda{argument},&returned.method(:<<))
      
      returned.should be == expected
    end
    $fixnum_class_num = $fixnum_class_num + 1
  end

  def self.test_op_enumerator(recv, op, parameter)
    
    expected = Array.new
    recv.send(op, parameter).each(&expected.method(:<<))
    
    _classname = "INTEGERNUMTEST#{$fixnum_class_num}"
    
    it "receiver #{recv}.#{op}(#{parameter}) should return #{expected} #{expected.class}" do
    fastruby(
      "class #{_classname}
          def foo(parameter)
            #{recv}.#{op}(parameter.call)
          end
        end
      "
    
    )
    
      returned_array = Array.new
      eval(_classname).new.foo( lambda{parameter} ).each(&returned_array.method(:<<))

      returned_array.should be == expected
    end
    
    $fixnum_class_num = $fixnum_class_num + 1
  end

  
  def self.test_unary_op_block(recv, op)
    _classname = "INTEGERNUMTEST#{$fixnum_class_num}"
    
    expected = Array.new
    recv.send(op, &expected.method(:<<))
    
    it "receiver #{recv}.#{op} should return #{expected} #{expected.class}" do
    fastruby(
      "class #{_classname}
          def foo(&blk)
            #{recv}.#{op}(&blk)
          end
        end
      "
    
    )
    
      returned = Array.new
      eval(_classname).new.foo(&returned.method(:<<))
      
      returned.should be == expected
    end
    $fixnum_class_num = $fixnum_class_num + 1
  end
  
  def self.test_unary_op(recv, op, expected = recv.send(op))
    _classname = "INTEGERNUMTEST#{$fixnum_class_num}"
    
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

  def self.test_unary_op_enumerator(recv, op)
    
    expected = Array.new
    recv.send(op).each(&expected.method(:<<))
    
    _classname = "INTEGERNUMTEST#{$fixnum_class_num}"
    
    it "receiver #{recv}.#{op} should return #{expected} #{expected.class}" do
    fastruby(
      "class #{_classname}
          def foo
            #{recv}.#{op}
          end
        end
      "
    
    )
    
      returned_array = Array.new
      eval(_classname).new.foo.each(&returned_array.method(:<<))
      
      returned_array.should be == expected
    end
    $fixnum_class_num = $fixnum_class_num + 1
  end

  [:integer?, :odd?, :even?, :succ, :next, :pred, :chr, :ord, :to_i, :to_int, :floor, :ceil, :truncate, :round].each do |op|
    test_unary_op(32,op)
    test_unary_op(77,op)
  end
  
  [:times].each do |op|
    test_unary_op_enumerator(77, op)
    test_unary_op_block(77, op)
  end

  test_op_block(77, :upto, 90)
  test_op_block(77, :downto, 60)
  test_op_enumerator(77, :upto, 90)
  test_op_enumerator(77, :downto, 60)
  
  it "1.upto(3).to_a should be [1,2,3]" do
    1.upto(3).to_a.should be == [1,2,3]
  end

  it "3.downto(1).to_a should be [3,2,1]" do
    3.downto(1).to_a.should be == [3,2,1]
  end

end
