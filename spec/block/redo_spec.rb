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
  
  class ::WB4
    fastruby <<EOS
    def foo
      yield(5)
    end
  
    def bar
      a = true
      foo do |n|
        if a
          a = false
          n = 555
          redo
        end
        n
      end
    end
EOS
  end

  it "should NOT restore variable arguments on block when calling redo" do
    wb4 = ::WB4.new
    wb4.bar.should be == 555
  end

end