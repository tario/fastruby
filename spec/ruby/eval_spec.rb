require "fastruby"

describe FastRuby, "fastruby" do
  fastruby "
    class EVALX01
      def foo(code)
        a = 3
        eval(code)
      end
    end
  "

  it "should eval local variable" do
    EVALX01.new.foo('a').should be == 3
  end 

  it "should raise NameError when trying to eval undefined variable" do
    lambda {
      EVALX01.new.foo('b')
    }.should raise_error(NameError)
  end 
end
