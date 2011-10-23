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
end