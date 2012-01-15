require "fastruby"
require "fastruby/sexp_extension"
require "sexp"
require "ruby_parser"
require "edges_helper"

describe FastRuby::FastRubySexp, "FastRubySexp" do
  include EdgesHelper

  assert_graph_defn("should have edges for rescue","
    def foo
      begin
          b
        rescue
          a
          retry
        end
      end") do |sexp, edges|

    {sexp.find_tree(:rescue)[1] => [:a,sexp.find_tree(:rescue)], 
    :a => sexp.find_tree(:retry), 
    sexp.find_tree(:retry) => :b
    }
  end
end
