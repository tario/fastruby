require "fastruby"

describe FastRuby::FastRubySexp, "FastRubySexp" do

  def self.test_binary_operator(op, classname, input, expected)
    it "should accept native operator + with two numbers" do
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
end
