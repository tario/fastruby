require "fastruby"

describe FastRuby, "fastruby" do
  it "should compile fastruby code with two methods" do
    class ::E1
      fastruby "
        def foo
          12
        end

        def bar
          15
        end
      "
    end

    e1 = ::E1.new
    e1.foo.should be == 12
    e1.bar.should be == 15
  end

  it "should compile fastruby code with class definition and one method" do
    fastruby "
      class ::E2
        def foo
          12
        end
      end
    "

    e2 = ::E2.new
    e2.foo.should be == 12
  end

  it "should compile fastruby code with class definition and two methods" do
    fastruby "
      class ::E3
        def foo
          12
        end
        def bar
          15
        end
      end
    "

    e3 = ::E3.new
    e3.foo.should be == 12
    e3.bar.should be == 15
  end

end