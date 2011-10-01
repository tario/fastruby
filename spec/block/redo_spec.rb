require "fastruby"

describe FastRuby, "fastruby redo statement" do
  class ::WB1
    fastruby "
      def bar
        yield
      end

      def foo
        sum = 0
        bar do
          sum = sum + 1
          redo if sum<10
        end

        sum
      end
    "
  end

  it "should execute basic redo" do
    wb1 = ::WB1.new
    wb1.foo.should be == 10
  end

  class ::WB2
      def bar
        yield
      end

    fastruby "

      def foo
        sum = 0
        bar do
          sum = sum + 1
          redo if sum<10
        end

        sum
      end
    "
  end

  it "should execute basic redo (called method is in ruby)" do
    wb2 = ::WB2.new
    wb2.foo.should be == 10
  end

  class ::WB3
    fastruby "
      def foo
        redo
      end
    "
  end

  it "should raise LocalJumpError when invoked illegal redo" do
    wb3 = ::WB3.new

    lambda {
      wb3.foo
    }.should raise_error(LocalJumpError)
  end

end