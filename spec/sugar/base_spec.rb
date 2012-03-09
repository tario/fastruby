require "fastruby"

describe FastRuby, "fastruby sexp graph" do
  it "should allow define fastruby method using fastruby block" do
    class FRBSUGAR1
      fastruby do
        def frbsugar1_foo(a)
          _static{INT2FIX(FIX2INT(a)+1)}
        end
      end
    end

    FRBSUGAR1.new.frbsugar1_foo(100).should be == 101
  end

  it "should allow define fastruby method using fastruby block with fastruby_only" do
    class FRBSUGAR2
      fastruby(:fastruby_only => true) do
        def frbsugar2_foo(a)
          _static{INT2FIX(FIX2INT(a)+1)}
        end
      end
    end

    lambda {
      FRBSUGAR2.new.frbsugar2_foo(100)
    }.should raise_error(NoMethodError)
  end
end
