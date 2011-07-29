require "fastruby"

describe FastRuby, "fastruby" do

  class ::C1
    fastruby '
      def foo
        ret = 0
        if true
          ret = 32
        end
        ret
      end
    '
  end

  it "should execute if when the condition is true" do
    ::C1.new.foo.should be == 32
  end

  class ::C2
    fastruby '
      def foo
        ret = 0
        if false
          ret = 32
        end
        ret
      end
    '
  end

  it "should execute if when the condition is false" do
    ::C2.new.foo.should be == 0
  end


  class ::C3
    fastruby '
      def foo
        ret = 0
        if false
          ret = 32
        else
          ret = 16
        end
        ret
      end
    '
  end

  it "should execute if with else when the condition is false" do
    ::C3.new.foo.should be == 16
  end
end