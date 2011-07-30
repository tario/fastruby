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

  it "should deny wrong type assignments at runtime by default" do
    lambda {
    ::Y1.new.foo("test string")
    }.should raise_error(FastRuby::TypeMismatchAssignmentException)
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

  it "should deny wrong type assignments at runtime when validate_lvar_types is true" do
    lambda {
    ::Y2.new.foo("test string")
    }.should raise_error(FastRuby::TypeMismatchAssignmentException)
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

  it "should NOT deny wrong type assignments at runtime when validate_lvar_types is false" do
    lambda {
    ::Y3.new.foo("test string")
    }.should_not raise_error
  end


  class ::Y4
    fastruby "
      def foo(x)
		x+1
      end
    "
  end

  it "should builds be re-entrants, multiple calls should not produce any error if the first call works" do
    lambda {
	::Y4.build([Y4,Fixnum],:foo)
	::Y4.build([Y4,Fixnum],:foo)
	::Y4.build([Y4,Fixnum],:foo)
	
	::Y4.new.foo(1).should be ==2
    }.should_not raise_error
  end
end