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

end