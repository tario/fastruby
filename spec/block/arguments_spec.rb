require "fastruby"

describe FastRuby, "fastruby" do
  class ::VO1
    fastruby "
      def foo(x)
        yield(*x)
      end
    "
  end

  it "should allow pass splat arguments to yield" do
    ::VO1.new.foo([1,2,3]) do |x,y,z|
      x.should be == 1
      y.should be == 2
      z.should be == 3
    end
  end
  
  class ::VO2
    fastruby "
      def foo(x)
        yield(1,*x)
      end
    "
  end

  it "should allow pass normal and splat arguments to yield" do
    ::VO2.new.foo([2,3,4]) do |a,x,y,z|
      a.should be == 1
      x.should be == 2
      y.should be == 3
      z.should be == 4
    end
  end
  
  class ::VO3
    fastruby "
      def foo(x)
        yield(1,2,*x)
      end
    "
  end

  it "should allow pass two normal args and one splat argument to yield" do
    ::VO3.new.foo([3,4,5]) do |a,b,x,y,z|
      a.should be == 1
      b.should be == 2
      x.should be == 3
      y.should be == 4
      z.should be == 5
    end
  end
  
  it "should take only the object argument when trying to splat a non-array" do
    ::VO1.new.foo("non-array") do |x|
      x.should be == "non-array"
    end
  end
  
  class ::VO4
    
    def bar
      yield(1,2,3,4)
    end
    
    fastruby "
      def foo
        bar do |*y|
          y
        end
      end
    "
  end
  
  it "should allow masgn arguments on block passes" do
    ::VO4.new.foo.should be == [1,2,3,4]
  end
  

  class ::VO5
    
    fastruby "
      def bar
        yield(1,2,3,4)
      end
    
      def foo
        bar do |*y|
          y
        end
      end
    "
  end
  
  it "should allow masgn arguments on block passes (fastruby call)" do
    ::VO5.new.foo.should be == [1,2,3,4]
  end
  
  
  class ::VO6
    
    def bar
      yield(1,2,3,4)
    end
    
    fastruby "
      def foo
        bar do |a,b,*y|
          y
        end
      end
    "
  end
  
  it "should allow normal arguments with masgn arguments on block passes" do
    ::VO6.new.foo.should be == [3,4]
  end
  
  class ::VO7
    fastruby "
      def foo
        pr = proc do |*x|
          x
        end
        pr.call(32)
      end
    "
  end

  it "should allow splat arguments on proc block" do
    ::VO7.new.foo.should be == [32]
  end

  class ::VO8
    fastruby "
      def foo
        pr = proc do |*x|
          x
        end
        pr.call(32,33,34)
      end
    "
  end

  it "should allow multiple splat arguments on proc block" do
    ::VO8.new.foo.should be == [32,33,34]
  end
  
end