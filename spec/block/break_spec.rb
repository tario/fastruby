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

  class ::V5
    fastruby "

      def each
        yield(1)
        yield(2)
        yield(3)
      end

      def foo
        sum = 0
        each do |a|
          sum = sum + a
          break if a == 2
        end

        sum
      end
    "
  end

  it "should execute basic test iterating an array with a conditional break (method with block on fastruby)" do
    ::V5.new.foo.should be == 3
  end

  class ::V6
    fastruby "
      def foo(ary)
        ary.each do |a|
          break 85 if a == 2
        end
      end
    "
  end

  it "should allow return value on parent method using break" do
    ::V6.new.foo([1,2,3]).should be == 85
  end

  class ::V7

    attr_reader :a

    fastruby "

      def each
        yield(1)
        yield(2)
        yield(3)
      ensure
        @a = 87
      end

      def foo
        each do |a|
          break if a == 2
        end
      end
    "
  end

  it "should execute ensure on parent frame when using break" do
    x = ::V7.new

    x.foo
    x.a.should be == 87
  end

end