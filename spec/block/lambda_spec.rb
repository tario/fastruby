require "fastruby"

describe FastRuby, "fastruby" do
  class ::LL1
    fastruby "
      def foo
        a = 16
        lambda {|x|
          a+x
        }
      end
    "
  end

  it "lambda must be able to access local variables" do
    ::LL1.new.foo.call(16).should be == 32
  end

    fastruby "
  class ::LL2
      def foo
        a = 16
        lambda {|x|
          a+x
        }
      end

      def bar
      end
  end
    "

  it "lambda must be able to access local variables, after another unrelated method is called" do
    ll2 = ::LL2.new
    lambda_object = ll2.foo
    ::LL2.new.bar
    lambda_object.call(16).should be == 32
  end

    fastruby "
  class ::LL3
      def foo(a)
        lambda {|x|
          a+x
        }
      end

      def bar(y)
        lambda_object = foo(16)
        foo(160)
        lambda_object.call(y)
      end
  end
    "

  it "lambda must be able to access local variables, after another unrelated method is called (from fastruby)" do
    ll3 = ::LL3.new
    ll3.bar(1).should be == 17
  end
end