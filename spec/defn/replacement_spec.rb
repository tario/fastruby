require "fastruby"

describe FastRuby, "fastruby" do
  it "should allow define method with array arguments" do
    fastruby "
      class JU1
        def foo
          6
        end
      end
    "
    
    ::JU1.new.foo
    
    fastruby "
      class JU1
        def foo
          9
        end
      end
    "
    
    ::JU1.new.foo.should be == 9
  end

end