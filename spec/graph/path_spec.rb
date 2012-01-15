require "fastruby"
require "fastruby/sexp_extension"

describe FastRuby::Graph, "fastruby sexp graph" do
  include FastRuby  
  it "should read paths from simple graph" do
    graph = Graph.new 1 => [2]
    array = []
    graph.each_path_from(1) do |path|
      path_array = []
      path.each(&path_array.method(:<<))
      array << path_array
    end

    array.should include([1,2])
    array
  end
end

