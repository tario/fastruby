require "fastruby"

describe FastRuby::FastRubySexp, "FastRubySexp" do

  it "should accept native operator + with two numbers" do
    fastruby "
    class STATICX1_1
      def foo(a)
        _static {
           INT2FIX(FIX2INT(a)+_native{1})
        }
      end
    end
    "
    
    STATICX1_1.new.foo(1).should be == 2
  end
end
