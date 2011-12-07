require "fastruby"

describe FastRuby, "fastruby" do
  class ::D5
    fastruby '
      def foo(a,b)
        a == b
      end
    '
  end

  it "should execute unless when the condition is false" do
    ::D5.new.foo(1,1).should be == true
    ::D5.new.foo(1,2).should be == false
  end

  class ::D6
    fastruby '
      def foo(a,b)
        a and b
      end
    '
  end

  it "should execute unless when the condition is false" do
    ::D6.new.foo(false,false).should be == false
    ::D6.new.foo(true,false).should be == false
    ::D6.new.foo(false,true).should be == false
    ::D6.new.foo(true,true).should be == true
  end

  class ::D7
    fastruby '
      def foo(a,b)
        a or b
      end
    '
  end

  it "should execute unless when the condition is false" do
    ::D7.new.foo(false,false).should be == false
    ::D7.new.foo(true,false).should be == true
    ::D7.new.foo(false,true).should be == true
    ::D7.new.foo(true,true).should be == true
  end

  class ::D8
    fastruby '
      def foo(a)
       not a
      end
    '
  end

  it "should execute unless when the condition is false" do
    ::D8.new.foo(false).should be == true
    ::D8.new.foo(true).should be == false
  end
end