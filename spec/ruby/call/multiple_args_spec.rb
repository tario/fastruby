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


  it "should allow basic array expansion with block" do
        class ::CY3
          def bar(*x)
            x
          end
        fastruby "
          def foo(x)
            bar(*x) do
	        end
          end
        "
        end
        
        ::CY3.new.foo([1,2,3]).should be == [1,2,3]
  end

  it "should allow basic array expansion plus single argument with block" do
        class ::CY4
          def bar(*x)
            x
          end
        fastruby "
          def foo(x)
            bar(100,*x) do
		   end
          end
        "
        end
        
        ::CY4.new.foo([1,2,3]).should be == [100,1,2,3]
  end
  
        class ::CY5
          def bar(*x)
            x
          end
          fastruby "
            def foo(x)
              bar(*x)
            end
          "
        end
        
  it "should allow long array of 8192 elements" do
    ::CY5.new.foo([0]*8192).should be == [0]*8192
  end

  it "should allow non-array element (should be converted to array)" do
    ::CY5.new.foo(0).should be == [0]
  end

  
end