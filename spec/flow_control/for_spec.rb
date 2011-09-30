require "fastruby"

describe FastRuby, "for statement" do
  class ::OX1
    fastruby '
      def foo(a)
        for i in a
        end
      end
    '
  end

  it "should invoke each" do
    ox1 = ::OX1.new
    a = [1,2,3]
    a.should_receive(:each)
    ox1.foo(a)
  end

  class ::OX2
    fastruby '
      def foo(a)
        ret = 0

        for i in a
          ret = ret + i
        end

        ret
      end
    '
  end

  it "should read i on each for iteration" do
    ox2 = ::OX2.new
    a = [1,2,3]
    ox2.foo(a).should be == 6
  end

end
