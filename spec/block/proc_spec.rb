require "fastruby"

describe FastRuby, "fastruby" do
  class ::LN1
    fastruby "
      def foo
        a = 16
        proc {|x|
          a+x
        }
      end
    "
  end

  it "proc must be able to access local variables" do
    ::LN1.new.foo.call(16).should be == 32
  end

    fastruby "
  class ::LN2
      def foo
        a = 16
        proc {|x|
          a+x
        }
      end

      def bar
      end
  end
    "

  it "proc must be able to access local variables, after another unrelated method is called" do
    ll2 = ::LN2.new
    proc_object = ll2.foo
    ::LN2.new.bar
    proc_object.call(16).should be == 32
  end

    fastruby "
  class ::LN3
      def foo(a)
        proc {|x|
          a+x
        }
      end

      def bar(y)
        proc_object = foo(16)
        foo(160)
        proc_object.call(y)
      end
  end
    "

  it "proc must be able to access local variables, after another unrelated method is called (from fastruby)" do
    ll3 = ::LN3.new
    ll3.bar(1).should be == 17
  end

    fastruby "
  class ::LN4
      def foo
        proc {|x|
          yield(x)
        }
      end

      def bar
        z = 99
        foo do |x|
          x+z
        end
      end

      def xt
        proc_object = bar()
        proc_object.call(1)
      end
  end
    "

  it "proc must be able to access local variables of parent scopes through yield (from fastruby)" do
    ll4 = ::LN4.new
    ll4.xt.should be == 100
  end

  it "proc must be able to access local variables of parent scopes through yield" do
    ll4 = ::LN4.new
    proc_object = ll4.bar
    proc_object.call(1).should be == 100
  end

  it "proc must be able to access local variables of parent scopes through yield on ruby" do
    ll4 = ::LN4.new

    a = 99

    proc_object = ll4.foo do |x|
      x+a
    end
    proc_object.call(1).should be == 100
  end

  def self.next_sentence(sname)
    fastruby "
      class ::LN5#{sname}
          def foo
            proc {
              #{sname} 100
            }
          end
      end
    "

    it "proc #{sname}'s must act as block next" do
      eval("LN5"+sname).new.foo.call.should be == 100
    end
  end

  next_sentence("next")
  next_sentence("break")
  next_sentence("return")

  def self.illegal_jump(sname)
    fastruby "
      class ::LN6#{sname}
          def foo
            proc {
              yield
            }
          end

          def bar
            foo do
              #{sname} 9
            end
          end
      end
    "

    it "#{sname} inside block should raise LocalJumpError" do
       ll6 = eval("::LN6"+sname).new
       lambda {
         ll6.bar.call
         }.should raise_error(LocalJumpError)
    end
  end

  illegal_jump("return")
  illegal_jump("break")

end
