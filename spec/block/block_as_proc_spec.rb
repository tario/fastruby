require "fastruby"

describe FastRuby, "fastruby" do
  class ::VYE1
    fastruby "
      def foo(&block)
      end
    "
  end

  it "should allow method receiveing block" do
    lambda {
      ::VYE1.new.foo do
        
      end
    }.should_not raise_error
  end

  class ::VYE2
    fastruby "
      def foo(&block)
        block.call
      end
    "
  end

  it "should allow call block" do
    lambda {
      executed = 0
      ::VYE2.new.foo do
        executed = 1
      end
      
      executed.should be == 1
    }.should_not raise_error
  end

  class ::VYE3
    fastruby "
      def foo(&block)
        block.call(64)
      end
    "
  end

  it "should allow call block with argument" do
    lambda {
      recv_a = 0
      ::VYE3.new.foo do |a|
        recv_a = a
      end
      
      recv_a.should be == 64
    }.should_not raise_error
  end

  class ::VYEE
  end

  class ::VYE4
    fastruby "
      def bar(x)
        def x.foo(&block)
        end
      end
    "
  end

  it "should allow singleton method receiveing block" do
    x = ::VYEE.new
    ::VYE4.new.bar(x)
    x.foo do
    end
  end

  class ::VYE5
    fastruby "
      def bar(x)
        def x.foo(&block)
          block.call
        end
      end
    "
  end

  it "should allow singleton method receiveing and call block" do
    x = ::VYEE.new
    ::VYE5.new.bar(x)

    executed = 0
    x.foo do
      executed = 1
    end

    executed.should be == 1
  end

end