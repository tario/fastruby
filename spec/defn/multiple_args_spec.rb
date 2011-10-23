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
  
  it "should allow define method with normal argument plus array arguments and call with one argument" do
    lambda {
      fastruby "
        class ::CF5
          def foo(a, *x)
            x
          end
        end
      "
      
      ::CF5.new.foo(1).should be == []
    }.should_not raise_error
  end  

  it "should allow define method with normal argument plus array arguments and call with two arguments" do
    lambda {
      fastruby "
        class ::CF6
          def foo(a, *x)
            x
          end
        end
      "
      
      ::CF6.new.foo(1,2).should be == [2]
    }.should_not raise_error
  end  
  
  it "should allow define method with normal argument plus array arguments and call with one argument" do
    lambda {
      fastruby "
        class ::CF7
          def foo(a, *x)
            a
          end
        end
      "
      
      ::CF7.new.foo(1).should be == 1
    }.should_not raise_error
  end  

  it "should allow define method with normal argument plus array arguments and call with two arguments" do
    lambda {
      fastruby "
        class ::CF8
          def foo(a, *x)
            a
          end
        end
      "
      
      ::CF8.new.foo(1,2).should be == 1
    }.should_not raise_error
  end
  
  it "should allow define method with array arguments and call with no arguments from fastruby" do
    lambda {
      fastruby "
        class ::CF9
          def foo(*x)
            x
          end
          
          def bar
            foo
          end
        end
      "
      
      ::CF9.new.bar.should be == []
    }.should_not raise_error
  end  

  it "should allow define method with array arguments and call with one argument from fastruby" do
    lambda {
      fastruby "
        class ::CF10
          def foo(*x)
            x
          end
          
          def bar
            foo(1)
          end
        end
      "
      
      ::CF10.new.bar.should be == [1]
    }.should_not raise_error
  end  

  it "should allow define method with array arguments and call with two arguments from fastruby" do
    lambda {
      fastruby "
        class ::CF11
          def foo(*x)
            x
          end
          
          def bar
            foo(1,2)
          end
        end
      "
      
      ::CF11.new.bar.should be == [1,2]
    }.should_not raise_error
  end  
  
  it "should allow define method with normal argument plus array arguments and call with one argument from fastruby" do
    lambda {
      fastruby "
        class ::CF12
          def foo(a, *x)
            x
          end
          
          def bar
            foo(1)
          end
        end
      "
      
      ::CF12.new.bar.should be == []
    }.should_not raise_error
  end  

  it "should allow define method with normal argument plus array arguments and call with two arguments from fastruby" do
    lambda {
      fastruby "
        class ::CF13
          def foo(a, *x)
            x
          end
          
          def bar
            foo(1,2)
          end
        end
      "
      
      ::CF13.new.bar.should be == [2]
    }.should_not raise_error
  end  
  
  it "should allow define method with normal argument plus array arguments and call with one argument from fastruby" do
    lambda {
      fastruby "
        class ::CF14
          def foo(a, *x)
            a
          end
          
          def bar
            foo(1)
          end
        end
      "
      
      ::CF14.new.bar.should be == 1
    }.should_not raise_error
  end  

  it "should allow define method with normal argument plus array arguments and call with two arguments from fastruby" do
    lambda {
      fastruby "
        class ::CF15
          def foo(a, *x)
            a
          end

          def bar
            foo(1.2)
          end
        end
      "
      
      ::CF15.new.foo(1,2).should be == 1
    }.should_not raise_error
  end
  
  it "should raise ArgumentError when trying to call with too few arguments" do
    lambda {
      fastruby "
        class ::CF16
          def foo(a, *x)
            a
          end
        end
      "
      
      ::CF16.new.foo
    }.should raise_error(ArgumentError)
  end
  
  it "should raise ArgumentError when trying to call with too few arguments from fastruby" do
    lambda {
      fastruby "
        class ::CF17
          def foo(a, *x)
            a
          end
          
          def bar
            foo
          end
        end
      "
      
      ::CF17.new.bar
    }.should raise_error(ArgumentError)
  end
  
  it "should call Array#to_s when infering array type for splat argument" do
      fastruby "
        class ::CF18
          def foo(*x)
            x.to_s
          end
        end
      "

      ::CF18.new.foo(1,2,3,4,5).should be == "12345"
  end
end