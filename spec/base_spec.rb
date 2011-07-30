require "fastruby"

class X
  fastruby "
    def foo(a,b)
      return a+b
    end
  "
  def foo2(a,b)
    return a+b
  end

  fastruby "
    def foo3(a)
      9
    end
    "

end

describe FastRuby, "fastruby" do

  def self.test_foo(a,b)
    it "should execute a method with + of #{a.class}" do
      x = X.new
      x.foo(a,b).should be == x.foo2(a,b)
    end
  end

  test_foo(5353531,6000000)
  test_foo("5353531","6000000")
  test_foo([1,2,3], [5,6])

  it "methods without return should return last expression result" do
    X.new.foo3(0).should be == 9
  end

  class ::X2
   fastruby "
    def foo
      0
    end
   "
  end

  it "methods without arguments should be called" do
    ::X2.new.foo.should be == 0
  end

  class ::X3
    fastruby "
      def foo
       while false
       end
       0
      end
    "
  end

  it "should execute methods with while" do
    ::X3.new.foo.should be == 0
  end

  class ::X4
    fastruby "
      def foo
       i = 10
       i
      end
    "
  end

  it "should assign and read locals" do
    ::X4.new.foo.should be == 10
  end

  class ::X5
    fastruby "
      def foo
       i = 10
       while i > 0
        i = i - 1
       end
       0
      end
    "
  end

  it "should run 10 iterations" do
    ::X5.new.foo.should be == 0
  end

  class ::A1
    fastruby "
      def foo
        i = 9
      end
    "
  end

  it "should compile a methd with lvar assignment as the last instruction" do
    ::A1.new.foo.should be == 9
  end

  class ::B2
    fastruby "
      def foo
        self
      end
    "
  end
  class ::A2
    fastruby "
      def foo(b2)
        b2.foo
      end
    "
  end

  it "should read self of nested frame" do
    b2 = ::B2.new
    ::A2.new.foo(b2).should be == b2
  end

  class ::A3
    fastruby "
      def foo(x)
        x.to_i(16)
      end
    "
  end

  it "should execute native methods with variable arguments" do
    ::A3.new.foo("40").should be == 64
  end

  class ::A4
    fastruby "
      def foo(x)
        x.to_i
      end
    "
  end

  it "should execute native methods with variable arguments (and no arguments is passed)" do
    ::A4.new.foo("40").should be == 40
  end

  class ::A5
    fastruby "
      def bar(x)
        x
      end
     "

    fastruby "
      def foo(x,a,b)
        bar(
          if (x)
            a
          else
            b
          end
        )
      end
    "
  end

  it "should compile inline if when passed as argument in a method call" do
    ::A5.new.foo(true,11,12).should be == 11
  end

  class ::A6
    fastruby "
      def bar(x)
        x
      end
     "

    fastruby "
      def foo(x,a,b)
        bar(
          if (x)
            x.to_s
            a
          else
            x.to_s
            b
          end
        )
      end
    "
  end

  it "should compile inline if when passed as argument in a method call. if as many lines" do
    ::A6.new.foo(true,11,12).should be == 11
  end

  class ::A7
    fastruby "
      def bar(x)
        x
      end
     "

    fastruby "
      def foo(x,a,b)
        bar(
          if (x)
            x.to_s
            a
          else
            x.to_s
            b
          end
        ) {
        }
      end
    "
  end

  it "should compile inline if when passed as argument in a method call with block. if has many lines" do
    ::A7.new.foo(true,11,12).should be == 11
  end

  class ::A8
    fastruby "
      def foo(x)
          a = if (x)
                x.to_s
                1
              else
                x.to_s
                2
              end

          a
      end
    "
  end

  it "should compile inline if at lvar assignment" do
    ::A8.new.foo(true).should be == 1
    ::A8.new.foo(false).should be == 2
  end

  class ::A9
    fastruby "
      def foo(x)
            if (x)
              x.to_s
              1
            else
              x.to_s
              2
            end
      end
    "
  end

  it "should compile inline if at end of method" do
    ::A9.new.foo(true).should be == 1
    ::A9.new.foo(false).should be == 2
  end

  class ::A10
    fastruby '
      def foo
        a = nil
        inline_c "plocals->a = INT2FIX(143)"
        a
      end
    '
  end

  it "should compile inline C when using inline_c directive" do
    ::A10.new.foo().should be == 143;
  end

  class ::A11
    fastruby '
      def foo(b)
        a = b
        inline_c " if (plocals->a == Qnil) {
            plocals->a = INT2FIX(43);
          } else {
            plocals->a = INT2FIX(44);
          }
          "
        a
      end
    '
  end

  it "should compile inline C if when using inline_c directive" do
    ::A11.new.foo(nil).should be == 43;
    ::A11.new.foo(true).should be == 44;
  end

  class ::A12
    fastruby '
      def foo(b)
        a = b
        x = inline_c(" if (plocals->a == Qnil) {
            plocals->a = INT2FIX(43);
          } else {
            plocals->a = INT2FIX(44);
          }
          ")
        a
      end
    '
  end

  it "should compile inline C when it is used as rvalue and return nil when no return is specified" do
    ::A12.new.foo(55).should be == 44;
  end

  class ::A13
    fastruby '
      def foo(b)
        a = b
        x = inline_c(" if (plocals->a == Qnil) {
            plocals->a = INT2FIX(43);
          } else {
            plocals->a = INT2FIX(44);
          }
          ")
        x
      end
    '
  end

  it "should compile inline C when it is used as rvalue and assign nil if not return is specified" do
    ::A13.new.foo(55).should be == nil;
  end

  class ::A14
    fastruby '
      def foo(b)
        a = b
        x = inline_c(" if (plocals->a == Qnil) {
            return INT2FIX(43);
          } else {
            return INT2FIX(44);
          }
          ")
        x
      end
    '
  end

  it "should compile inline C when it is used as rvalue and assign the returned expression" do
    ::A14.new.foo(55).should be == 44;
  end

end