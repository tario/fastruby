require "fastruby"

describe FastRuby, "fastruby" do
  it "should allow basic return" do
   fastruby "
      class ::P1
        def foo
          return 1
        end
      end
    "
    ::P1.new.foo.should be == 1
  end

  it "should allow return from inside a block" do
   fastruby "
      class ::P2
        def bar
          yield
        end

        def foo
          bar do
            return 8
          end

          return 0
        end
      end
    "
    ::P2.new.foo.should be == 8
  end

  it "should allow basic return on singleton method" do
   fastruby "
      class ::P3
      end

      class ::P31
        def bar(x)
          def x.foo
            return 1
          end
        end
      end
    "

    p3 = ::P3.new
    ::P31.new.bar(p3)
    p3.foo.should be == 1
  end

  it "should allow return from inside a block on a singleton method" do
   fastruby "
      class ::P4
        def bar
          yield
        end
      end

      class ::P41
        def bar(x)
          def x.foo
            bar do
              return 8
            end
            return 0
          end
        end
      end
    "
    p4 = ::P4.new
    ::P41.new.bar(p4)
    p4.foo.should be == 8
  end

  it "should execute ensure when ensure impl has a return" do
   fastruby "
      class ::P5
        def a
          @a
        end

        def foo
          begin
            return 16
          ensure
            @a = 9
          end

          return 32
        end
      end
    "
    p5 = ::P5.new
    p5.foo.should be == 16
    p5.a.should be ==9
  end
end