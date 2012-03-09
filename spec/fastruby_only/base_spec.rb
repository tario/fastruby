require "fastruby"

describe FastRuby, "FastRuby" do
  it "should accept fastruby_only option" do
    fastruby "
    class FRONLY1
      def foo
        100
      end
    end
    ", :fastruby_only => true
  end
end
