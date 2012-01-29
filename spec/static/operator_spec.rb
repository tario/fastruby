require "fastruby"

describe FastRuby::FastRubySexp, "FastRubySexp" do

  def self.test_binary_operator(op, classname, input, expected)
    it "should accept native operator #{op} with two numbers input:#{input} expected:#{expected}}" do
      fastruby "
      class #{classname}
        def foo(a)
          _static {
             INT2FIX(FIX2INT(a)#{op}2)
          }
        end
      end
      "
      
      eval(classname).new.foo(input).should be == expected
    end
  end
  
  test_binary_operator("+", "STATICX1_1", 10, 12)
  test_binary_operator("-", "STATICX1_2", 10, 8)
  test_binary_operator("*", "STATICX1_3", 10, 20)
  test_binary_operator("/", "STATICX1_4", 10, 5)

  (3..4).each do |i|
    test_binary_operator(">", "STATICX1_5_#{i}", i, 1)
  end

  (-1..2).each do |i|
    test_binary_operator(">", "STATICX1_6_#{i.to_s.gsub('-','__')}", i, 0)
  end

  (-1..1).each do |i|
    test_binary_operator("<", "STATICX1_6_#{i.to_s.gsub('-','__')}", i, 1)
  end

  (2..3).each do |i|
    test_binary_operator("<", "STATICX1_7_#{i}", i, 0)
  end
  

  (2..4).each do |i|
    test_binary_operator(">=", "STATICX1_8_#{i}", i, 1)
  end

  (-1..1).each do |i|
    test_binary_operator(">=", "STATICX1_9_#{i.to_s.gsub('-','__')}", i, 0)
  end

  (-1..2).each do |i|
    test_binary_operator("<=", "STATICX1_10_#{i.to_s.gsub('-','__')}", i, 1)
  end

  (3..4).each do |i|
    test_binary_operator("<=", "STATICX1_11_#{i}", i, 0)
  end
  

  (3..5).each do |i|
    test_binary_operator("==", "STATICX1_12_#{i}", i, i == 2 ? 1 : 0)
  end
  
  (3..5).each do |i|
    test_binary_operator("===", "STATICX1_13_#{i}", i, i == 2 ? 1 : 0)
  end
  
  def self.test_bool_operator(code, classname, expected)
    it "should execute boolean operation #{code} expected:#{expected}}" do
      fastruby "
      class #{classname}
        def foo
          _static {
             if (#{code})
               INT2FIX(40)
             else
               INT2FIX(20)
             end
          }
        end
      end
      "
      
      eval(classname).new.foo.should be == expected
    end
  end
  
  test_bool_operator "4 and 4", "STATIC1_14", 40
  test_bool_operator "4 or 4", "STATIC1_15", 40
end
