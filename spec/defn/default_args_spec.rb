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
end
