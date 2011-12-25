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

  it "should have edges" do
    FastRuby::FastRubySexp.parse("def foo; end").should respond_to(:edges)
  end

  it "should have two edges for empty method" do
    get_defn_edges("def foo; end") do |sexp, edges|
      edges.should include([sexp[3][1],sexp[3]]) # scope after block
      edges.should include([sexp[3][1][1],sexp[3][1]]) # block after nil
    end
  end

  it "should have two edges for method returning literal 1" do
    get_defn_edges("def foo; 0; end") do |sexp, edges|
      edges.should include([sexp[3][1],sexp[3]]) # scope after block
      edges.should include([sexp[3][1][1],sexp[3][1]]) # block after lit
    end
  end

  it "should have three edges for method invoking method a and then literal 1" do
    get_defn_edges("def foo; a; 1; end") do |sexp, edges|
      scope_tree = sexp[3]
      block_tree = scope_tree[1]

      edges.should include([block_tree[1],block_tree[2]]) # literal 1 after ca
      edges.should include([block_tree[2],block_tree]) # block after last item of block
      edges.should include([block_tree,scope_tree]) # scope after block
    end
  end

  it "should have three edges for method invoking method with two arguments" do
    get_edges("x.foo(y,z)") do |sexp,edges|
      args_tree = sexp[3]

      edges.should include([args_tree[1],args_tree[2]]) # argument 2 after argument 1
      edges.should include([sexp[1],args_tree[1]]) # argument 1 after recv
      edges.should include([args_tree[2],sexp]) # argument 2 after argument 1

    end  
  end
end
