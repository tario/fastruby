require "fastruby"
require "fastruby/sexp_extension"

describe FastRuby::Graph, "fastruby sexp graph" do
  include FastRuby  
  it "should allow create empty graph" do
    graph = Graph.new 
  end

  it "should allow add edges with add_edge" do
    graph = Graph.new
    graph.add_edge(1,2)
    graph.edges.count.should be == 1
    graph.edges.first.should be == [1,2]
  end

  it "should return 0 edges for an empty graph" do
    graph = Graph.new 
    graph.edges.count.should be == 0
  end

end
