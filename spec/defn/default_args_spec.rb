require "fastruby"

describe FastRuby, "fastruby" do
  it "should allow one optional argument" do
    fastruby "
      class CFX1
        def foo(a=0)
          a
        end
      end
    "
  end

  it "should allow one optional argument and should return the default when no specified" do
    fastruby "
      class CFX2
        def foo(a=0)
          a
        end
      end
    "
    
    CFX2.new.foo.should be == 0
  end

  it "should allow one optional argument and should return the passed value when specified" do
    fastruby "
      class CFX3
        def foo(a=0)
          a
        end
      end
    "
    
    CFX3.new.foo(99).should be == 99
  end

  fastruby "
    class CFX4
      def foo(a=7,b=4)
        [a,b]
      end
    end
  "

  it "should allow two optional argument and should return the passed value when no arguments is passed" do
    cfx4 = CFX4.new
    cfx4.foo().should be == [7,4]
  end

  it "should allow two optional argument and should return the passed value when one argument is passed" do
    cfx4 = CFX4.new
    cfx4.foo(99).should be == [99,4]
  end

  it "should allow two optional argument and should return the passed value when two arguments are passed" do
    cfx4 = CFX4.new
    cfx4.foo(99,88).should be == [99,88]
  end

  fastruby "
    class CFX5
      def foo(a,b=4)
        [a,b]
      end
    end
  "

  it "should allow one mandatory and one optional argument and should return the passed value when one argument is passed" do
    cfx5 = CFX5.new
    cfx5.foo(99).should be == [99,4]
  end

  it "should allow one mandatory and one optional argument and should return the passed value when two arguments are passed" do
    cfx5 = CFX5.new
    cfx5.foo(99,88).should be == [99,88]
  end

  it "should raise ArgumentError when no arguments are passed" do
    lambda {
      cfx5 = CFX5.new
      cfx5.foo
    }.should raise_error(ArgumentError)
  end

  it "should raise ArgumentError when three arguments are passed" do
    lambda {
      cfx5 = CFX5.new
      cfx5.foo(1,2,3)
    }.should raise_error(ArgumentError)
  end


end
