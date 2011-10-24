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

end