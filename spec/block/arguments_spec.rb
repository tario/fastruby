require "fastruby"

describe FastRuby, "fastruby" do
  class ::VO1
    fastruby "
      def foo(x)
        yield(*x)
      end
    "
  end

  it "should allow pass splat arguments to yield" do
    ::VO1.new.foo([1,2,3]) do |x,y,z|
      x.should be == 1
      y.should be == 2
      z.should be == 3
    end
  end
end