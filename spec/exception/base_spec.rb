require "fastruby"

describe FastRuby, "fastruby" do
  it "should allow basic exception control" do
   fastruby "
      class ::L1
        def foo
          begin
          rescue
          end

          0
        end
      end
    "
    ::L1.new.foo.should be == 0
  end

  it "should allow basic exception control and catch exception" do
   fastruby "
      class ::L2
        def foo
          begin
            raise RuntimeError
          rescue RuntimeError
            return 1
          end

          0
        end
      end
    "

    lambda {
      ::L2.new.foo.should be == 1
    }.should_not raise_exception
  end

  it "should trap exception raised on ensure after return on parent frame" do
    
    fastruby <<ENDSTR
    
    class L3
      def foo
        yield
      ensure
        raise RuntimeError
      end
    
      def bar
        foo do
          return 4
        end
      end
    end
    
ENDSTR
    
    lambda {
      ::L3.new.bar
    }.should raise_exception(RuntimeError)
    
  end

end