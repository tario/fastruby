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

  class BahException < Exception
  end

  def self.basic_unhandled_exception(*exception_names)

    exception_names.each do |exception_name|
      it "should raise basic exception #{exception_name}" do

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

      it "should not raise basic exception #{exception_name} if rescued" do

        random_name = "::L6_" + rand(10000).to_s

        fastruby "
          class #{random_name}
              def foo
                begin
                raise #{exception_name}
                rescue #{exception_name}
                end
              end
          end
           "

        l = eval(random_name).new

        lambda {
          l.foo
        }.should_not raise_exception
      end

      it "should raise basic exception #{exception_name} even if rescued when the rescue is for another exception" do

        random_name = "::L7_" + rand(10000).to_s

        fastruby "
          class #{random_name}
              def foo
                begin
                  raise #{exception_name}
                rescue BahException
                end
              end
          end
           "

        l = eval(random_name).new

        lambda {
          l.foo
        }.should raise_exception(eval(exception_name))
      end

      it "should rescue basic exception #{exception_name} when raised from rubycode called from fastruby code" do

        random_name = "::L8_" + rand(10000).to_s
        random_name_2 = "::L8_" + rand(10000).to_s

        eval "
          class #{random_name_2}
            def bar
              raise #{exception_name}
            end
          end
        "

        fastruby "
          class #{random_name}
              def foo(x)
                x.bar
              end
          end
           "

        l1 = eval(random_name_2).new
        l2 = eval(random_name).new
        lambda {
          l2.foo(l1)
        }.should raise_exception(eval(exception_name))
      end

      it "should rescue basic exception #{exception_name} from fastruby code when raised from rubycode" do

        random_name = "::L9_" + rand(10000).to_s
        random_name_2 = "::L9_" + rand(10000).to_s

        eval "
          class #{random_name_2}
            def bar
              raise #{exception_name}
            end
          end
        "

        fastruby "
          class #{random_name}
              def foo(x)
                begin
                  x.bar
                rescue #{exception_name}
                end
              end
          end
           "

        l1 = eval(random_name_2).new
        l2 = eval(random_name).new
        lambda {
          l2.foo(l1)
        }.should_not raise_exception
      end

    end
  end

  basic_unhandled_exception("Exception")
  basic_unhandled_exception("RuntimeError")
  basic_unhandled_exception("StandardError")
  basic_unhandled_exception("Errno::ENOENT")

  it "should accept else with rescue" do

    random_name = "::L11_" + rand(10000).to_s
    fastruby "
          class #{random_name}
              def foo
                begin
                  raise Exception
                rescue Exception
                  return 111
                else
                  return 222
                end
              end
          end
           "

    l = eval(random_name).new
    l.foo.should be == 111
   end

  it "should accept else with rescue, when no exception is raised" do

    random_name = "::L12_" + rand(10000).to_s
    fastruby "
          class #{random_name}
              def foo
                begin
                rescue Exception
                  return 111
                else
                  return 222
                end
              end
          end
           "

    l = eval(random_name).new
    l.foo.should be == 222
   end

end