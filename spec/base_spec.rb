require "fastruby"

class X
  fastruby "
    def foo(a,b)
      return a+b
    end
  "
  def foo2(a,b)
    return a+b
  end

  fastruby "
    def foo3(a)
      9
    end
    "

end

describe FastRuby, "fastruby" do

  def self.test_foo(a,b)
    it "should execute a method with + of #{a.class}" do
      x = X.new
      x.foo(a,b).should be == x.foo2(a,b)
    end
  end

  test_foo(5353531,6000000)
  test_foo("5353531","6000000")
  test_foo([1,2,3], [5,6])

  it "methods without return should return last expression result" do
    X.new.foo3(0).should be == 9
  end

  class ::X2
   fastruby "
    def foo
      0
    end
   "
  end

  it "methods without arguments should be called" do
    ::X2.new.foo.should be == 0
  end

  class ::X3
    fastruby "
      def foo
       while false
       end
       0
      end
    "
  end

  it "should execute methods with while" do
    ::X3.new.foo.should be == 0
  end

  class ::X4
    fastruby "
      def foo
       i = 10
       i
      end
    "
  end

  it "should assign and read locals" do
    ::X4.new.foo.should be == 10
  end

  class ::X5
    fastruby "
      def foo
       i = 10
       while i > 0
        i = i - 1
       end
       0
      end
    "
  end

  it "should run 10 iterations" do
    ::X5.new.foo.should be == 0
  end

  class ::A1
    fastruby "
      def foo
        i = 9
      end
    "
  end

  it "should compile a methd with lvar assignment as the last instruction" do
    ::A1.new.foo.should be == 9
  end

end