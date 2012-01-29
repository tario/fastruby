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
end
