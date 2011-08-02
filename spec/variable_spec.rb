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

  class ::U5
    fastruby "
      def foo
        U5C = 11
      end
    "
  end

  it "should write constants" do
    ::U5.new.foo

    U5C.should be == 11
  end

  class ::U6
    fastruby "
      def foo
        U6C
      end
    "
  end

  it "should read constants" do
    ::U6C = 11
    ::U6.new.foo.should be == 11
  end


  class ::U7
    class U71
      fastruby "
        def foo
          U7C = 11
        end
      "
    end
  end

  it "should write nested constants" do
    ::U7::U71.new.foo
    ::U7::U71::U7C.should be == 11

    lambda {
    ::U7::U7C
    }.should raise_error

    lambda {
    ::U7C
    }.should raise_error
  end

  class ::U8
    class U81
      fastruby "
        def foo
          U8C
        end
      "
    end
  end
  it "should read  nested constants" do
    ::U8::U81::U8C = 11
    ::U8::U81.new.foo.should be == 11
  end

end