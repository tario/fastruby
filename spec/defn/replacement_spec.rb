require "fastruby"

describe FastRuby, "fastruby" do
  it "should allow replace methods after they are called and compiled at runtime" do
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

  it "should allow replace methods after they are called and compiled at runtime (through other method)" do
    fastruby "
      class JU2
        def foo
          6
        end
        
        def bar
          foo
        end
      end
    "
    
    ::JU2.new.bar
    
    fastruby "
      class JU2
        def foo
          9
        end
      end
    "
    
    ::JU2.new.bar.should be == 9
  end
end