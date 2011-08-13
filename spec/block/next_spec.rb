require "fastruby"

describe FastRuby, "fastruby" do
  class ::W1
    fastruby "
      def foo(ary)
        sum = 0
        ary.each do |a|
          next if a == 2
          sum = sum + a
        end

        sum
      end
    "
  end

  it "should execute basic test iterating an array" do
    ::W1.new.foo([1,2,3]).should be == 4
  end

  class ::W2
    fastruby "
      def foo
        next
      end
    "
  end

  it "should raise LocalJumpError with illegal next" do
    lambda {
    ::W2.new.foo
    }.should raise_error(LocalJumpError)
  end

  class ::W3
    attr_reader :x, :y

    fastruby "
      def bar
        @x = yield(1)
        @y = yield(2)
      end

      def foo
        bar do |a|
          next 16 if a == 1
          next 32 if a == 2
        end
      end
    "
  end

  it "should return values on block using next" do
     x = ::W3.new
     x.foo
     x.x.should be == 16
     x.y.should be == 32
  end

end