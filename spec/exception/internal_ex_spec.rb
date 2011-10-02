require "fastruby"

describe FastRuby, "fastruby" do

  it "should trap 'no block given" do
    fastruby "
      class LLJ1
        attr_accessor :a

        def bar
          yield
        end

        def foo
          bar # this will raise LocalJumpError
        ensure
          @a = 1
        end
      end
    "

    llj1 = LLJ1.new

    lambda {
      llj1.foo
    }.should raise_error(LocalJumpError)

    llj1.a.should be == 1
  end


  it "should trap 'TypeError" do
    fastruby "
      class LLJ2
        attr_accessor :a

        def bar
          4::X
        end

        def foo
          bar # this will raise TypeError
        ensure
          @a = 1
        end
      end
    "

    llj2 = LLJ2.new

    lambda {
      llj2.foo
    }.should raise_error(TypeError)

    llj2.a.should be == 1
  end

  it "should trap FastRuby::TypeMismatchAssignmentException" do
    fastruby "
      class LLJ3
        attr_accessor :a

        def bar
          a = 0
          lvar_type(a,Fixnum)
          a = 'wrong value'
        end

        def foo
          bar # this will raise FastRuby::TypeMismatchAssignmentException
        ensure
          @a = 1
        end
      end
    ", :validate_lvar_types => true

    llj3 = LLJ3.new

    lambda {
      llj3.foo
    }.should raise_error(FastRuby::TypeMismatchAssignmentException)

    llj3.a.should be == 1
  end

end