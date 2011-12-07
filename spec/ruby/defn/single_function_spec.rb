require "fastruby"

describe FastRuby, "fastruby" do
  it "should allow define single method (without class)" do
    fastruby "
      def foo
      end
    "
  end

  it "should allow define and call single method (without class)" do
    fastruby "
      def foo
        
      end
    "
    foo
  end
  
  it "should allow define method from inside another method" do
    class ::YZU1
    fastruby "
      def foo
        def bar
          77
        end
      end
    "
    end
    
    ::YZU1.new.foo
  end
  
  it "should allow define and call method from inside another method" do
    class ::YZU2
    fastruby "
      def foo
        def bar
          99
        end
      end
    "
    end

    yzu2 = ::YZU2.new
    yzu2.foo
    yzu2.bar.should be == 99
  end  

end
