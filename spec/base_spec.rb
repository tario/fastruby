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
end