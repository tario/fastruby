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

end