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

  it "should allow splat arguments with default arguments " do
    fastruby "
      class CFX6
        def foo(x=44,*y)
        end
      end
    "
  end

  fastruby "
      class CFX7
        def foo(x=44,*y)
          x
        end
      end
    "

  it "should allow splat arguments with default arguments accepting no arguments " do
    CFX7.new.foo.should be == 44
  end

  it "should allow splat arguments with default arguments accepting one argument" do
    CFX7.new.foo(55).should be == 55
  end

  fastruby "
      class CFX8
        def foo(x=44,*y)
          y
        end
      end
    "

  it "should allow splat arguments with default arguments accepting no arguments" do
    CFX8.new.foo.should be == []
  end

  it "should allow splat arguments with default arguments accepting one arguments" do
    CFX8.new.foo(55).should be == []
  end

  it "should allow splat arguments with default arguments accepting two arguments" do
    CFX8.new.foo(55,66).should be == [66]
  end

  it "should allow splat arguments with default arguments accepting three arguments" do
    CFX8.new.foo(55,66,67,68).should be == [66,67,68]
  end

  fastruby "
      class CFX9
        def foo(a,x=44,*y)
          a
        end
      end
    "

  it "should allow splat arguments with default arguments accepting one argument" do
    CFX9.new.foo(55).should be == 55
  end

  it "should allow splat arguments with default arguments accepting two argument" do
    CFX9.new.foo(55,66).should be == 55
  end

  it "should allow splat arguments with default arguments accepting three argument" do
    CFX9.new.foo(55,66,77).should be == 55
  end

  fastruby "
      class CFX10
        def foo(a,x=44,*y)
          x
        end
      end
    "
  it "should allow splat arguments with default arguments accepting one argument" do
    CFX10.new.foo(55).should be == 44
  end

  it "should allow splat arguments with default arguments accepting two argument" do
    CFX10.new.foo(55,66).should be == 66
  end

  it "should allow splat arguments with default arguments accepting three argument" do
    CFX10.new.foo(55,66,77).should be == 66
  end

  fastruby "
      class CFX11
        def foo(a,x=44,*y)
          y
        end
      end
    "

  it "should raise ArgumentError with splat arguments with default arguments when no arguments are passed" do
    lambda {
      CFX11.new.foo
    }.should raise_error(ArgumentError)
  end

  it "should allow splat arguments with default arguments accepting one argument" do
    CFX11.new.foo(55).should be == []
  end

  it "should allow splat arguments with default arguments accepting two argument" do
    CFX11.new.foo(55,66).should be == []
  end

  it "should allow splat arguments with default arguments accepting three argument" do
    CFX11.new.foo(55,66,77).should be == [77]
  end
  
  fastruby "
      class CFX12
        def foo(a=0,&block)
          a
        end
      end
    "

  it "should allow splat arguments with default with block arguments accepting no argument" do
    CFX12.new.foo() {
      
    }.should be == 0
  end

  it "should allow splat arguments with default with block arguments accepting one argument" do
    CFX12.new.foo(44) {
      
    }.should be == 44
  end
  
  fastruby "
      class CFX13
        def foo(a=0,&block)
          block.call
        end
      end
    "

  it "should allow splat arguments with default with block arguments accepting no argument" do
    CFX13.new.foo() {
      66
    }.should be == 66
  end

  it "should allow splat arguments with default with block arguments accepting one argument" do
    CFX13.new.foo(44) {
      77
    }.should be == 77
  end

      class CFX14
        def foo
          55
        end
      end

  fastruby "
      class CFX15
        def foo(cfx14,b = cfx14.foo)
        end
      end
    "

  it "should execute default blocks when no argument is passed" do
    cfx14 = CFX14.new
    cfx15 = CFX15.new
    
    cfx14.should_receive :foo
    
    cfx15.foo(cfx14)
  end

  it "should not execute default blocks when argument is passed" do
    cfx14 = CFX14.new
    cfx15 = CFX15.new
    
    cfx14.should_not_receive :foo
    
    cfx15.foo(cfx14,99)
  end

  it "should allow if on default argument" do
    fastruby "
      class ::CFX16
        def foo(a, b = if a
              87
            else
              55
            end
          )
          b
        end
      end
    "


    cfx16 = ::CFX16.new
    
    cfx16.foo(false).should be == 55
    cfx16.foo(true).should be == 87
    cfx16.foo(true,99).should be == 99
    cfx16.foo(false,99).should be == 99
  end
  
end
