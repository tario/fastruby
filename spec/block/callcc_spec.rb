require "fastruby"

describe FastRuby, "fastruby" do
  class ::N1
    fastruby "
      def bar(cc)
        cc.call(75)
      end

      def foo
        callcc do |cc|
          bar(cc)
        end
      end
    "
  end

  it "should execute callcc on fastruby" do
    ::N1.new.foo.should be == 75
  end

  class ::N2
   def bar(cc)
     cc.call(76)
   end

    fastruby "
      def foo
        callcc do |cc|
          bar(cc)
        end
      end
    "
  end

  it "should execute callcc from ruby" do
    ::N2.new.foo.should be == 76
  end

  class ::N3
    fastruby "
      def foo(n_)
        n = n_

        val = 0
        cc = nil

        x = callcc{|c| cc = c; nil}

        val = val + x if x
        n = n - 1

        cc.call(n) if n > 0

        val
      end
    "
  end

  it "should execute callcc from ruby" do
    ::N3.new.foo(4).should be == 6
  end

end