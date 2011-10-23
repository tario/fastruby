require "fastruby"

describe FastRuby, "fastruby" do
  def self.test_arguments(x)
    it "should allow #{x} arguments calling to cfunc" do
      
          arguments = (0..x).map(&:to_s).join(",")
      
            fastruby "
          class ::CYR#{x}
              def foo
                a = []
                a.infer(Array).push(#{arguments})
                a
              end
          end
            "
          
          eval("::CYR#{x}").new.foo.should be == eval("[#{arguments}]")
    end
  end
  
  test_arguments(10)
  test_arguments(15)
  test_arguments(20)
  
  (23..27).each do |i|
    test_arguments(i)
  end
  
  test_arguments(20)
  
    
  def self.test_fastruby_arguments(argnum)
    it "should allow #{argnum} arguments calling fastruby" do
      
          arguments_name = (0..argnum-1).map{|x| "a"+x.to_s}.join(",")
          arguments = (0..argnum-1).map(&:to_s).join(",")
      
            fastruby "
          class ::CYR1_#{argnum}
              def foo(#{arguments_name})
                [#{arguments_name}]
              end
          end
            "
          
          array = eval("[#{arguments}]")
          
          eval("::CYR1_#{argnum}").new.foo(*array).should be == array 
    end
  end
  
  (8..12).each do |i|
    test_fastruby_arguments(i)
  end
end