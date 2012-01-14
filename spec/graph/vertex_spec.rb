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

  it "should allow read vertex from graph with one vertex" do
    graph = Graph.new 1 => [1]
    graph.vertexes.count.should be == 1
    graph.vertexes.should include(1)
  end

  it "should allow read vertex from graph with two vertexes" do
    graph = Graph.new 1 => [1,2]
    graph.vertexes.count.should be == 2
    graph.vertexes.should include(1)
    graph.vertexes.should include(2)
  end

  it "should allow allow read vertex outputs" do
    graph = Graph.new 1 => [1]

    array = []
    graph.each_vertex_output(1, &array.method(:<<))

    array.should include(1)
  end

  it "should allow read vertex outputs" do
    graph = Graph.new 1 => [2]

    array = []
    graph.each_vertex_output(1, &array.method(:<<))

    array.should include(2)

    array = []
    graph.each_vertex_output(2, &array.method(:<<))

    array.should be == []
  end


  it "should allow read vertex outputs with no blocks (returning sets)" do
    graph = Graph.new 1 => [2]
    graph.each_vertex_output(1).should include(2)
    graph.each_vertex_output(2).count.should == 0
  end
end
