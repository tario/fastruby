require "fastruby"
require "fastruby/sexp_extension"
require "sexp"
require "ruby_parser"
require "edges_helper"

describe FastRuby::FastRubySexp, "FastRubySexp" do
  include EdgesHelper

  assert_graph("should generate edges for or","a or b",2) do |sexp, edges|
    {:a => :b, :b => sexp}
  end

  assert_graph("should generate edges for and","a and b",2) do |sexp, edges|
    {:a => :b, :b => sexp}
  end
end
