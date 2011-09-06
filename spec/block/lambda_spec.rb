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
end