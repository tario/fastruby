require "fastruby"

describe FastRuby, "fastruby" do
  class ::X6
    fastruby "
      def foo(ary)
        ary.each do |a|
        end
        0
      end
    "
  end

  it "should compile blocks" do
    ::X6.new.foo([1,2,3]).should be == 0
  end

  class ::X7
    fastruby "
      def foo(ary)
        ary.map do |a|
          0
        end
      end
    "
  end

  it "should compile blocks with code inside" do
    ::X7.new.foo([1,2,3]).should be == [0,0,0]
  end

  class ::X8
    fastruby "
      def foo(ary)
        ary.map do |a|
          a
        end
      end
    "
  end

  it "should compile blocks with code inside refering block arguments" do
    ::X8.new.foo([1,2,3]).should be == [1,2,3]
  end

  class ::X9
    fastruby "
      def foo(hash)
        hash.map do |k,v|
          k+v
        end
      end
    "
  end

  it "should compile blocks with code inside refering multiple block arguments" do
    ::X9.new.foo({1 => 2, 3 => 4}).sort.should be == [3,7]
  end

  class ::Y10
    def bar(arg1)
      yield
      arg1
    end
  end

  class ::X10
    fastruby "
      def foo(obj, arg1)
        obj.bar(arg1) do |a|
        end
      end
    "
  end

  it "should compile iter calls with arguments" do
    ::X10.new.foo(::Y10.new, 10).should be == 10
  end

  class ::Y11
    def bar(arg1, arg2)
      yield
      arg1+arg2
    end
  end

  class ::X11
    fastruby "
      def foo(obj, arg1, arg2)
        obj.bar(arg1, arg2) do |a|
        end
      end
    "
  end

  it "should compile iter calls with multiple arguments" do
    ::X11.new.foo(::Y11.new, 10, 9).should be == 19
  end

  class ::X12
    fastruby "
      def foo(ary)
        a = 1
        ary.map do |x|
          a
        end
      end
    "
  end

  it "should allow accessing local variables from block" do
    ::X12.new.foo([1,2,3,4]).should be == [1,1,1,1]
  end

  class ::X13
    fastruby "
      def foo(ary)
        a = 1
        ary.map do |x|
          a+x
        end
      end
    "
  end

  it "should allow accessing local variables and block parameters from block" do
    ::X13.new.foo([1,2,3,4]).should be == [2,3,4,5]
  end

  class ::Y14
    fastruby "
      def bar
        block_given?
      end
    "
  end

  class ::X14
    fastruby "
      def foo(y)
        y.bar
      end
    "
  end

  it "method calls should not repass blocks" do
    ::X14.new.foo(::Y14.new){ }.should be == false
  end

  class ::X15
    fastruby "
      def foo
        bar
      end
    "

    private
      def bar
        true
      end
  end

  it "should allow calls to private methods" do
    ::X15.new.foo.should be == true
  end

  class ::X16
    fastruby "
      def foo
        bar do
          12
        end
      end
    "

    def bar
      yield
    end
  end

  it "should allow calls with block to self methods" do
    ::X16.new.foo.should be == 12
  end

  class ::X17
    fastruby "
      def foo(z)
        i = 9
        z.each do |x|
          i = x
          0
        end
        i
      end
    "
  end

  it "should allow assignment of locals from blocks" do
    ::X17.new.foo([1,2,3]).should be == 3
  end

  class ::X18
    fastruby "
      def foo
        yield
      end
    "
  end

  it "should allow block calls" do
    ::X18.new.foo{ 9 }.should be == 9
  end

  class ::Y19
    fastruby "
      def bar
        yield
      end
    "
  end

  class ::X19
    fastruby "
      def foo(y)
        y.bar {
          9
        }
      end
    "
  end

  it "should execute block class between fastruby methods when no block is passed" do
    ::X19.new.foo(::Y19.new).should be == 9
  end

  it "should execute block class between fastruby methods when block is passed" do
    ::X19.new.foo(::Y19.new){}.should be == 9
  end

  class ::X20
    fastruby "
      def foo
        yield(1)
      end
    "
  end

  it "should execute block from fastruby methods with one argument" do
    ::X20.new.foo do |n1|
      n1.should be == 1
    end
  end

  class ::X21
    fastruby "
      def foo
        yield(1,2)
      end
    "
  end

  it "should execute block from fastruby methods with two arguments" do
    ::X21.new.foo do |n1,n2|
      n1.should be == 1
      n2.should be == 2
    end
  end

end