require "fastruby"

describe FastRuby, "fastruby" do
  it "should allow basic exception control" do
   fastruby "
      class ::L1
        def foo
          begin
          rescue
          end

          0
        end
      end
    "
    ::L1.new.foo.should be == 0
  end

  it "should allow basic exception control and catch exception" do
   fastruby "
      class ::L2
        def foo
          begin
            raise RuntimeError
          rescue RuntimeError
            return 1
          end

          0
        end
      end
    "

    lambda {
      ::L2.new.foo.should be == 1
    }.should_not raise_exception
  end

  it "should allow basic exception control and ensure" do
   fastruby "
      class ::L3
        def foo

          a = 0

          begin
            raise RuntimeError
          rescue RuntimeError
          ensure
            a = 2
          end

          a
        end
      end
    "

    lambda {
      ::L3.new.foo.should be == 2
    }.should_not raise_exception
  end

  it "should allow basic exception control and ensure without rescue" do
      class ::L4
        attr_reader :a

        fastruby "
          def foo
            begin
              raise RuntimeError
            ensure
              @a = 2
            end
          end
       "
      end

    l4 = ::L4.new

    lambda {
      l4.foo
    }.should raise_exception(Exception)

    l4.a.should be == 2
  end

  it "should raise basic exception RuntimeError" do
      class ::L5
        fastruby "
          def foo
            raise RuntimeError
          end
       "
      end

    l5 = ::L5.new

    lambda {
      l5.foo
    }.should raise_exception(RuntimeError)
  end

end