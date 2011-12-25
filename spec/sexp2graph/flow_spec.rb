require "fastruby"
require "fastruby/sexp_extension"
require "sexp"
require "ruby_parser"

describe FastRuby::FastRubySexp, "FastRubySexp" do
  def get_defn_edges(code)
    sexp = FastRuby::FastRubySexp.parse(code)

    edges = Array.new
    sexp[3].edges.each do |tree_orig, tree_dest|
      edges << [tree_orig, tree_dest]
    end

    yield(sexp, edges)
  end  

  def get_edges(code)
    sexp = FastRuby::FastRubySexp.parse(code)

    edges = Array.new
    sexp.edges.each do |tree_orig, tree_dest|
      edges << [tree_orig, tree_dest]
    end

    yield(sexp, edges)
  end

  it "should have two edges for if" do
    get_edges("if a; b; else; c; end") do |sexp, edges|
      edges.size.should be == 2
      edges.should include([sexp[1],sexp[2]]) # true block after condition
      edges.should include([sexp[1],sexp[3]]) # false block after condition
    end
  end

  it "should have only one edge for if without else" do
    get_edges("if a; b; end") do |sexp, edges|
      edges.size.should be == 2
      edges.should include([sexp[1],sexp[2]]) # true block after condition
    end
  end
end
