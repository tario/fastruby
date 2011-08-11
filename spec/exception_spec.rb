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

  def self.basic_unhandled_exception(*exception_names)

    exception_names.each do |exception_name|
      it "should raise basic exception RuntimeError" do

        random_name = "::L5_" + rand(10000).to_s

        fastruby "
          class #{random_name}
              def foo
                raise #{exception_name}
              end
          end
           "

        l = eval(random_name).new

        lambda {
          l.foo
        }.should raise_exception(eval(exception_name))
      end
    end
  end

  basic_unhandled_exception("Exception")
  basic_unhandled_exception("RuntimeError")
  basic_unhandled_exception("StandardError")
end