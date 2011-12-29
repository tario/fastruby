require "fastruby"
require "fastruby/sexp_extension"
require "sexp"
require "ruby_parser"
require "edges_helper"

describe FastRuby::FastRubySexp, "FastRubySexp" do
  include EdgesHelper

  it "should have edges" do
    FastRuby::FastRubySexp.parse("def foo; end").should respond_to(:edges)
  end

  assert_graph_defn("should have two edges for empty method","def foo; end",2) do |sexp, edges|
    {sexp.find_tree(:block) => sexp.find_tree(:scope), sexp.find_tree(:nil) => sexp.find_tree(:block)}
  end

  assert_graph_defn("should have two edges for method returning literal 1","def foo; 0; end",2) do |sexp, edges|
   {sexp.find_tree(:block) => sexp.find_tree(:scope), sexp.find_tree(:lit) => sexp.find_tree(:block)}
  end

  assert_graph_defn("should have three edges for method invoking method a and then literal 1","def foo; a; 1; end",3) do |sexp, edges|
    {:a => sexp.find_tree(:lit), 
        sexp.find_tree(:lit) => sexp.find_tree(:block), 
        sexp.find_tree(:block) => sexp.find_tree(:scope) }
  end

  assert_graph("should have three edges for method invoking method with two arguments","x.foo(y,z)",3) do |sexp,edges|
    {:y => :z, :x => :y, :z => sexp}  
  end

  assert_graph_defn("should connect edges on block","def foo(x); x.bar; x1.foo(y,z); end") do |sexp,edges|
    block_tree = sexp.find_tree(:block)
    { block_tree[1] => :x1}
  end
end
