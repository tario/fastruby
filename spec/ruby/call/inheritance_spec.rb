require "fastruby"

describe FastRuby, "fastruby" do

  class INSPEC01
    fastruby(:fastruby_only => true) do
      def foo
        100
      end
    end
  end

  class INSPEC02 < INSPEC01
  end

  fastruby "
    class INSPEC03
      def bar(x)
        x.foo
      end
    end
  "

  it "should call parent implementation of methods with fastruby_only" do
    x = INSPEC02.new
    INSPEC03.new.bar(x).should be == 100
  end
end
