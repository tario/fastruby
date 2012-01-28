require "fastruby"

describe FastRuby::FastRubySexp, "FastRubySexp" do

  it "should accept _static keyword to compile static C calls" do
    fastruby "
    class STATICX1
      def foo
        _static {
           INT2FIX(100)
        }
      end
    end
    "
    
    STATICX1.new.foo.should be == 100
  end
end
