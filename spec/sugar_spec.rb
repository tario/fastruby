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
end