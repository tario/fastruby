require "fastruby"

describe FastRuby, "fastruby" do
  it "should alow definition of modules" do
    fastruby "
      module H1
      end
    "
  end

  it "should alow definition of modules with other code" do
    fastruby '
      print "defining module\n"

      module H2
      end
    '
  end

  it "should alow definition of method in modules" do
    fastruby '
      module H2
        def foo
          77
        end
      end
    '

    class H2C
     include H2
    end

    H2C.new.foo.should be == 77
  end

end