require "fastruby"
require "fastruby/sexp_extension"

describe FastRuby::Graph, "fastruby sexp graph" do
  include FastRuby  

  def self.assert_graph_paths(origin, paths, graph_hash) 
    it "should read paths #{paths.inspect} for graph #{graph_hash} from #{origin}" do
      graph = Graph.new graph_hash
            
      array = []
      graph.each_path_from(origin) do |path|
        path_array = []
        path.each(&path_array.method(:<<))
        array << path_array
      end

      paths.each do |path|
        array.should include(path)
      end
      array.count.should be == paths.count
 
      array
    end
  end

  assert_graph_paths(1, [[1,2]], 1 => [2] )
end

