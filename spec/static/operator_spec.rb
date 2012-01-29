require "fastruby"

describe FastRuby::FastRubySexp, "FastRubySexp" do

  def self.test_binary_operator(op, classname, input, expected)
    it "should accept native operator #{op} with two numbers input:#{input} expected:#{expected}}" do
      fastruby "
      class #{classname}
        def foo(a)
          _static {
             INT2FIX(FIX2INT(a)#{op}_native{2})
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
    test_binary_operator("<", "STATICX1_5_#{i.to_s.gsub('-','__')}", i, 1)
  end

  (2..3).each do |i|
    test_binary_operator("<", "STATICX1_6_#{i}", i, 0)
  end
end
