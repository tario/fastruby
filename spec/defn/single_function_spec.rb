require "fastruby"

describe FastRuby, "fastruby" do
  it "should allow define single method (without class)" do
    fastruby "
      def foo
      end
    "
  end

  it "should allow define and call single method (without class)" do
    fastruby "
      def foo
        
      end
    "
    foo
  end
end
