require "fastruby"

describe FastRuby, "fastruby" do
  class ::V1
    fastruby "
      def foo(ary)
        sum = 0
        ary.each do |a|
          sum = sum + a
        end

        sum
      end
    "
  end

  it "should execute basic test iterating an array" do
    ::V1.new.foo([1,2,3]).should be == 6
  end

  class ::V2
    fastruby "
      def foo(ary)
        sum = 0
        ary.each do |a|
          sum = sum + a
          break
        end

        sum
      end
    "
  end

  it "should execute basic test iterating an array with a break" do
    ::V2.new.foo([1,2,3]).should be == 1
  end

  class ::V3
    fastruby "
      def foo(ary)
        sum = 0
        ary.each do |a|
          sum = sum + a
          break if a == 2
        end

        sum
      end
    "
  end

  it "should execute basic test iterating an array with a conditional break" do
    ::V3.new.foo([1,2,3]).should be == 3
  end

  class ::V4
    fastruby "
      def foo
        break
      end
    "
  end

  it "should raise LocalJumpError with illegal break" do
    lambda {
    ::V4.new.foo
    }.should raise_error(LocalJumpError)
  end
end