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

  class ::B2
    fastruby "
      def foo
        self
      end
    "
  end
  class ::A2
    fastruby "
      def foo(b2)
        b2.foo
      end
    "
  end

  it "should read self of nested frame" do
    b2 = ::B2.new
    ::A2.new.foo(b2).should be == b2
  end

end