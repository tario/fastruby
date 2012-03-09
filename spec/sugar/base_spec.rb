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

end
