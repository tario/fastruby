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

end