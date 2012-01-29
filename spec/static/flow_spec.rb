require "fastruby"

describe FastRuby::FastRubySexp, "FastRubySexp" do
    fastruby "
      class STATICFLOW1
        def foo(a)
          _static do
            if (FIX2INT(a))
              INT2FIX(20)
            else
              INT2FIX(40)
            end
          end
        end
      end
    "
    
    
  def self.test_static_if(*args)
    args.each do |arg|
      it "should should evaluate #{arg} as #{arg != 0} on static if" do
        STATICFLOW1.new.foo(arg).should be == (arg == 0 ? 40 : 20)
      end
    end
  end

  test_static_if false.__id__, true.__id__, nil.__id__, 10, 11
  
  it "should allow static while" do
    fastruby "
      class STATICFLOW2
        def foo(a)
          ret = 0
          _static do
            while (FIX2INT(a) > 0)
              a = INT2FIX(FIX2INT(a) - 1)
              ret = INT2FIX(FIX2INT(ret) + 1)
            end
          end
          ret
        end
      end
    "
    
    STATICFLOW2.new.foo(7).should be == 7
    STATICFLOW2.new.foo(0).should be == 0
  end
end
