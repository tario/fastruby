require "fastruby"

describe FastRuby, "fastruby" do
  it "should alow definition of modules" do
    fastruby "
      module H1
      end
    "
  end
end