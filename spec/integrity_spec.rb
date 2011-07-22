require "fastruby"

describe FastRuby, "fastruby" do

  class ::Y1
    fastruby "
      def foo(x)
        i = 0
        lvar_type(i,Fixnum)
        i = x
        0
      end
    "
  end

  it "should deny wrong type assignments at build time by default" do
    lambda {
    ::Y1.new.foo("test string")
    }.should raise_error(FastRuby::BadTypeAssignment)
  end

  class ::Y2
    fastruby "
      def foo(x)
        i = 0
        lvar_type(i,Fixnum)
        i = x
        0
      end
    ", :validate_lvar_types => true
  end

  it "should deny wrong type assignments at build time when validate_lvar_types is true" do
    lambda {
    ::Y2.new.foo("test string")
    }.should raise_error(FastRuby::BadTypeAssignment)
  end

  class ::Y3
    fastruby "
      def foo(x)
        i = 0
        lvar_type(i,Fixnum)
        i = x
        0
      end
    ", :validate_lvar_types => false
  end

  it "should NOT deny wrong type assignments at build time when validate_lvar_types is false" do
    lambda {
    ::Y3.new.foo("test string")
    }.should_not raise_error
  end

end