require "fastruby"
require "fastruby/sexp_extension"

describe FastRuby::Graph, "fastruby sexp graph" do
  include FastRuby  
  it "should allow read vertex from empty graph" do
    graph = Graph.new 
    graph.vertexes
  end

  it "should allow read vertex from empty graph and it must be empty" do
    graph = Graph.new 
    graph.vertexes.count.should be == 0
  end

end
