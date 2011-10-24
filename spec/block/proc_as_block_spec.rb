require "fastruby"

describe FastRuby, "fastruby" do
  class ::VY1
    fastruby "
      def foo
        yield
      end
    "
  end

  it "should allow block as proc when calling from normal ruby" do
    executed = 0
    
    block = proc do 
      executed = 1
    end
    
    ::VY1.new.foo(&block)
    
    executed.should be == 1
  end

  class ::VY2
    fastruby "
      def foo
        yield
      end
      
      def bar(block)
        foo(&block)
      end
    "
  end

  it "should allow block as proc when calling from fastruby" do
    executed = 0
    
    block = proc do 
      executed = 1
    end
    
    ::VY2.new.bar(block)
    
    executed.should be == 1
  end

  class ::VY3
    fastruby "
      def foo
        yield(1)
      end
      
      def bar(block)
        foo(&block)
      end
    "
  end

  it "should allow block as proc when calling from fastruby with arguments" do
    executed = 0
    recv_x = nil
    
    block = proc do |x|
      recv_x = x       
      executed = 1
    end
    
    ::VY3.new.bar(block)
    
    recv_x.should be == 1
    executed.should be == 1
  end


end