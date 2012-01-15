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
  assert_graph_paths(1, [[1,3]], 1 => [3] )
  assert_graph_paths(1, [[1,4]], 1 => [4] )
  assert_graph_paths(3, [[3,2]], 3 => [2] )
  assert_graph_paths(4, [[4,2]], 4 => [2] )

  assert_graph_paths(1, [[1,2],[1,3]], 1 => [2,3] )

  assert_graph_paths(1, [[1,2,3]], 1 => [2], 2 => [3] )
  assert_graph_paths(1, [[1,2,3],[1,2,4]], 1 => [2], 2 => [3,4] )
  assert_graph_paths(1, [[1,2,4],[1,3,4]], 1 => [2,3], 2 => [4],3 => [4] )
  assert_graph_paths(1, [[1,2,3,4,5],[1,2,3,5],[1,3,5],[1,3,4,5]], 1 => [2,3], 2 => [3],3 => [4,5],4 => [5] )
end

