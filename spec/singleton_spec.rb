require "fastruby"

describe FastRuby, "fastruby" do

  it "should allow defining class methods" do
    fastruby '
      class X
        def self.foo
          9
        end
      end
    '
    X.foo.should be == 9
  end

  it "should allow defining class methods with blocks" do
    fastruby '
      class R2
        def self.bar
          yield
        end
      end
    '
    R2.bar{67}.should be == 67
  end

end