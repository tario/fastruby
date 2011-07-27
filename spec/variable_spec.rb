require "fastruby"

describe FastRuby, "fastruby" do

  class ::U1
    fastruby "
      def foo
        $au1 = 88
      end
    "
  end

  it "should write global variables" do
    ::U1.new.foo
    $au1.should be == 88
  end

  class ::U2
    fastruby "
      def foo
        $au2
      end
    "
  end

  it "should read global variables" do
    $au2 = 88
    ::U2.new.foo.should be == 88
  end

  class ::U3
    attr_accessor :au3

    fastruby "
      def foo
        @au3 = 88
      end
    "
  end

  it "should write instance variables" do
    u3 = ::U3.new
    u3.foo
    u3.au3.should be == 88
  end

  class ::U4
    attr_accessor :au4

    fastruby "
      def foo
        @au4
      end
    "
  end

  it "should read instance variables" do
    u4 = ::U4.new
    u4.au4 = 88
    u4.foo.should be == 88
  end

end