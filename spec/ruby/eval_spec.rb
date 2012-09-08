require "fastruby"

describe FastRuby, "fastruby" do
  fastruby "
    class EVALX01
      def foo(code)
        a = 3
        eval(code)
      end
    end
  "

  fastruby "
    class EVALX02
      def foo(code)
        c = 100
        eval(code)
        c
      end
    end
  "

  it "should eval local variable" do
    EVALX01.new.foo('a').should be == 3
  end 

  it "should raise NameError when trying to eval undefined variable" do
    lambda {
      EVALX01.new.foo('b')
    }.should raise_error(NameError)
  end 

  it "should allow assing local variables on eval" do
    EVALX02.new.foo('c = 43').should be == 43
  end

  it "should allow assing new defined local variables on eval" do
    EVALX01.new.foo('b = 43; b').should be == 43
  end

  fastruby "
    class EVALX03
      def foo
        a = 1
        b = 2
        c = 3
        binding
      end
    end
  "

  it "should allow eval on fastruby binding" do
    EVALX03.new.foo.eval("a").should be == 1
    EVALX03.new.foo.eval("b").should be == 2
    EVALX03.new.foo.eval("c").should be == 3
  end 

  fastruby "
    class EVALX04
      def foo(b, code)
        b.eval(code)
      end
    end
  " 

  def create_binding_0
    a = 32
    binding
  end

  it "should eval on bindings defined on ruby using Binding#eval" do
    EVALX04.new.foo(create_binding_0(), "a").should be == 32
  end 

  fastruby "
    class EVALX05
      def foo(b, code)
        eval(code,b)
      end
    end
  " 

  it "should eval on bindings defined on ruby passing binding on eval" do
    EVALX05.new.foo(create_binding_0(), "a").should be == 32
  end 

  it "should eval on bindings defined on fastruby using Binding#eval" do
    binding_ = EVALX03.new.foo
    EVALX04.new.foo(binding_, "c").should be == 3
  end 

  it "should eval on bindings defined on fastruby passing binding on eval" do
    binding_ = EVALX03.new.foo
    EVALX05.new.foo(binding_, "c").should be == 3
  end 
end
