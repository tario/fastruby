require "fastruby"

describe FastRuby, "FastRuby" do
  it "should accept fastruby_only option" do
    fastruby "
    class FRONLY1
      def foo
        100
      end
    end
    ", :fastruby_only => true
  end

  it "should accept fastruby_only option, methods defined with that option should not be callable from normal ruby" do
    fastruby "
    class FRONLY2
      def fronly2_foo
        100
      end
    end
    ", :fastruby_only => true

    lambda {
      FRONLY2.new.fronly2_foo
    }.should raise_error(NoMethodError)
  end

  it "should accept fastruby_only option, methods defined with that option should be callable from fastruby" do
    fastruby "
    class FRONLY3
      def foo
        100
      end
    end
    ", :fastruby_only => true

    fastruby "
    class FRONLY3
      def bar
        foo
      end
    end
    "
    
    FRONLY3.new.bar.should be == 100
  end
  
  it "should accept fastruby_only option, and two versions of the same method" do
    class FRONLY4
      def foo
        200
      end
    end

    fastruby "
    class FRONLY4
      def foo
        100
      end
    end
    ", :fastruby_only => true

    fastruby "
    class FRONLY4
      def bar
        foo
      end
    end
    "
    
    FRONLY4.new.bar.should be == 100
    FRONLY4.new.foo.should be == 200
  end
end
