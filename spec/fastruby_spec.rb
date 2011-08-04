require "fastruby"

describe FastRuby, "fastruby" do

  it "should do nothing when execute fastruby with nothing" do
    lambda {
    fastruby ""
    }.should_not raise_error
  end

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

end