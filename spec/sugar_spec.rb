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

  class ::E4
    def foo
    end
  end

  it "should compile standalone code and execute it inmediatly" do
    $e4 = ::E4
    fastruby "
      require 'fastruby'
      $e4.new.foo
    "
  end

  it "should compile standalone code togheter with classes and execute it inmediatly" do
    $e4 = ::E4
    fastruby "
      require 'fastruby'
      $e4.new.foo

      class ::E5
        def foo
          12
        end
        def bar
          15
        end
      end

    "

    e5 = ::E5.new
    e5.foo.should be == 12
    e5.bar.should be == 15
  end

  class ::E6
    attr_reader :called
    def foo
      @called = true
    end
  end
  it "should execute standalone code" do
    $e6 = ::E6.new
    fastruby "
      $e6.foo
    "
    $e6.called.should be == true
  end

  it "should execute standalone code inside a class definition" do
    $e6_1 = ::E6.new
    fastruby "
      class X
        $e6_1.foo
      end
    "
    $e6_1.called.should be == true
  end



end