require "fastruby"

describe FastRuby, "fastruby" do
  class ::Z1
    fastruby "
      def foo
        0
      end
    "
  end

  it "should compile Fixnum literals" do
    ::Z1.new.foo.should be == 0
  end

  class ::Z2
    fastruby "
      def foo
        'test string'
      end
    "
  end

  it "should compile string literals" do
    ::Z2.new.foo.should be == 'test string'
  end

  class ::Z3
    fastruby "
      def foo
        [1,2,3]
      end
    "
  end

  it "should compile array literals" do
    ::Z3.new.foo.should be == [1,2,3]
  end

  class ::Z4
    fastruby "
      def foo
        /aaa/
      end
    "
  end

  it "should compile regexp literals" do
    ::Z4.new.foo.should be == /aaa/
  end

  class ::Z5
    fastruby "
      def foo
        { 1 => 2, 3 => 4}
      end
    "
  end

  it "should compile hash literals" do
    ::Z5.new.foo.should be == { 1 => 2, 3 => 4}
  end

  class ::Z6
    fastruby "
      def foo
        nil
      end
    "
  end

  it "should compile nil" do
    ::Z6.new.foo.should be == nil
  end

  class ::Z7
    fastruby "
      def foo(a,b)
        (a..b)
      end
    "
  end

  def self.test_range(a,b)
    it "should compile range (#{a}..#{b})" do
      ::Z7.new.foo(a,b).should be == (a..b)
    end
  end

  test_range 0,0
  test_range 3,54
  test_range 'a', 'f'
  test_range 0.54,066

end
