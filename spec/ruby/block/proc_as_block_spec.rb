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


  class ::VY4
      def foo(a,b,c)
        yield(a,b,c)
      end
      
    
    fastruby "
      def bar(x,block)
        foo(*x,&block)
      end
    "
  end

  it "should allow block as proc when calling from fastruby with splat arguments" do
    executed = 0
    recv_a = nil
    recv_b = nil
    recv_c = nil
    
    block = proc do |a,b,c|
      recv_a = a
      recv_b = b
      recv_c = c
      executed = 1
    end
    
    ::VY4.new.bar([1,2,3],block)
    
    recv_a.should be == 1
    recv_b.should be == 2
    recv_c.should be == 3
    executed.should be == 1
  end

  class ::VY5
      def foo(a)
        yield(a)
      end
      
    
    fastruby "
      def bar(x,block)
        foo(*x,&block)
      end
    "
  end

  it "should allow pass symbols as blocks" do
    vy5 = ::VY5.new
    vy5.bar([44],:to_s).should be == "44"
  end


  class ::VY6
    fastruby "
      def foo(a)
        yield(a)
      end
    
      def bar(x,block)
        foo(x,&block)
      end
    "
  end

  it "should allow single arguments with block" do
    vy6 = ::VY6.new

    block = proc do |a| "44" end
    vy6.bar(44,block).should be == "44"
  end

  class ::VY7
      def foo(a)
        yield(a)
      end
      
    
    fastruby "
      def bar(x,block)
        foo(x,&block)
      end
    "
  end

  it "should allow single arguments with block calling ruby methods" do
    vy7 = ::VY7.new

    block = proc do |a| "44" end
    vy7.bar(44,block).should be == "44"
  end
end
