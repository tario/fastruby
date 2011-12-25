require "fastruby"
require "fastruby/sexp_extension"
require "sexp"
require "ruby_parser"

describe FastRuby::FastRubySexp, "FastRubySexp" do
  it "should have edges" do
    FastRuby::FastRubySexp.parse("def foo; end").should respond_to(:edges)
  end
end
