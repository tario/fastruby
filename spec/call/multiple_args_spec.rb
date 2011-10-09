require "fastruby"

describe FastRuby, "fastruby" do
  it "should allow basic array expansion" do
        class ::CY1
          def bar(*x)
            x
          end
        fastruby "
          def foo(x)
            bar(*x)
          end
        "
        end
        
        ::CY1.new.foo([1,2,3]).should be == [1,2,3]
  end

  it "should allow basic array expansion plus single argument" do
        class ::CY2
          def bar(*x)
            x
          end
        fastruby "
          def foo(x)
            bar(100,*x)
          end
        "
        end
        
        ::CY2.new.foo([1,2,3]).should be == [100,1,2,3]
  end
end