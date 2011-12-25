require "fastruby"
require "fastruby/sexp_extension"
require "sexp"
require "ruby_parser"

describe FastRuby::FastRubySexp, "FastRubySexp" do
  def get_edges(code)
    sexp = FastRuby::FastRubySexp.parse(code)

    edges = Array.new
    sexp[3].edges.each do |tree_orig, tree_dest|
      edges << [tree_orig, tree_dest]
    end

    yield(sexp, edges)
  end  

  it "should have edges" do
    FastRuby::FastRubySexp.parse("def foo; end").should respond_to(:edges)
  end

  it "should have two edges for empty method" do
    get_edges("def foo; end") do |sexp, edges|
      edges.should include([sexp[3][1],sexp[3]]) # scope after block
      edges.should include([sexp[3][1][1],sexp[3][1]]) # block after nil
    end
  end

end
