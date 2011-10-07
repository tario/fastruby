require "fastruby"

describe FastRuby, "fastruby" do
  it "should allow define method with array arguments" do
    lambda {
      fastruby "
        class CF1
          def foo(*x)
          end
        end
      "
    }.should_not raise_error
  end
  
  it "should allow define method with array arguments and call with no arguments" do
    lambda {
      fastruby "
        class ::CF2
          def foo(*x)
            x
          end
        end
      "
      
      ::CF2.new.foo().should be == []
    }.should_not raise_error
  end  

  it "should allow define method with array arguments and call with one argument" do
    lambda {
      fastruby "
        class ::CF3
          def foo(*x)
            x
          end
        end
      "
      
      ::CF3.new.foo(1).should be == [1]
    }.should_not raise_error
  end  

  it "should allow define method with array arguments and call with two arguments" do
    lambda {
      fastruby "
        class ::CF4
          def foo(*x)
            x
          end
        end
      "
      
      ::CF4.new.foo(1,2).should be == [1,2]
    }.should_not raise_error
  end  
  
  
end