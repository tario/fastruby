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

  it "should accept fastruby_only option, methods defined with that option should not be callable from normal ruby" do
    fastruby "
    class FRONLY2
      def foo
        100
      end
    end
    ", :fastruby_only => true

    lambda {
      FRONLY2.new.foo
    }.should raise_error(NoMethodError)
  end

end
