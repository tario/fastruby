require "fastruby"

describe FastRuby::FastRubySexp, "FastRubySexp" do

  it "should accept _static keyword to compile static C calls" do
    fastruby "
    class STATICX1
      def foo(a)
        _static {
           INT2FIX(FIX2INT(a))
        }
      end
    end
    "
    
    STATICX1.new.foo(100).should be == 100
  end
  
  it "should accept _native to accept native C semantic" do
    fastruby "
    class STATICX2
      def foo
        _static {
           INT2FIX(_native{100})
        }
      end
    end
    "
    
    STATICX2.new.foo.should be == 100
  end
  
  it "should accept _dynamic to activate ruby sematic inside _static block" do
    fastruby "
    class STATICX3
      def bar(a)
        a+1
      end
      
      def foo(a)
        _static {
           INT2FIX(
              FIX2INT(
                  _dynamic{bar(a)}
              )
           )
        }
      end
    end
    "
    
    STATICX3.new.foo(100).should be == 101
  end  
end
