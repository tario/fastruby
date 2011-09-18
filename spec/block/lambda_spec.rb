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

    fastruby "
  class ::LL4
      def foo
        lambda {|x|
          yield(x)
        }
      end

      def bar
        z = 99
        foo do |x|
          x+z
        end
      end

      def xt
        lambda_object = bar()
        lambda_object.call(1)
      end
  end
    "

  it "lambda must be able to access local variables of parent scopes through yield (from fastruby)" do
    ll4 = ::LL4.new
    ll4.xt.should be == 100
  end

  it "lambda must be able to access local variables of parent scopes through yield" do
    ll4 = ::LL4.new
    lambda_object = ll4.bar
    lambda_object.call(1).should be == 100
  end

  it "lambda must be able to access local variables of parent scopes through yield on ruby" do
    ll4 = ::LL4.new

    a = 99

    lambda_object = ll4.foo do |x|
      x+a
    end
    lambda_object.call(1).should be == 100
  end

  def self.next_sentence(sname)
    fastruby "
      class ::LL5#{sname}
          def foo
            lambda {
              #{sname} 100
            }
          end
      end
    "

    it "lambda #{sname}'s must act as block next" do
      eval("LL5"+sname).new.foo.call.should be == 100
    end
  end

  next_sentence("next")
  next_sentence("break")
  next_sentence("return")
end
