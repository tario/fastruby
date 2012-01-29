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
  
  it "should accept native operator - with two numbers" do
    fastruby "
    class STATICX1_1
      def foo(a)
        _static {
           INT2FIX(FIX2INT(a)-_native{8})
        }
      end
    end
    "
    
    STATICX1_1.new.foo(10).should be == 2
  end
  
  it "should accept native operator * with two numbers" do
    fastruby "
    class STATICX1_1
      def foo(a)
        _static {
           INT2FIX(FIX2INT(a)*_native{3})
        }
      end
    end
    "
    
    STATICX1_1.new.foo(3).should be == 9
  end
  
  it "should accept native operator / with two numbers" do
    fastruby "
    class STATICX1_1
      def foo(a)
        _static {
           INT2FIX(FIX2INT(a)/_native{3})
        }
      end
    end
    "
    
    STATICX1_1.new.foo(9).should be == 3
  end
end
