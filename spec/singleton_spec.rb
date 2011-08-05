require "fastruby"

describe FastRuby, "fastruby" do

  it "should allow defining class methods" do
    fastruby '
      class X
        def self.foo
          9
        end
      end
    '
    X.foo.should be == 9
  end

  it "should allow defining class methods with blocks" do
    fastruby '
      class R2
        def self.bar
          yield
        end
      end
    '
    R2.bar{67}.should be == 67
  end

  it "should call singleton methods from outside" do
    class R3
      def bar
        12
      end
    end

    fastruby '
      class R4
        def foo(x)
          def x.bar
            24
          end
        end
      end
    '

    r3 = R3.new
    R4.new.foo(r3)
    r3.bar.should be == 24
  end

end