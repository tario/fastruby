require "fastruby"
require "fastruby/sexp_extension"
require "sexp"
require "ruby_parser"
require "edges_helper"

describe FastRuby::FastRubySexp, "FastRubySexp" do
  include EdgesHelper

  assert_graph("should generate edges for local assignment","a = b",1) do |sexp, edges|
    {:b => sexp}
  end

  assert_graph("should generate edges for global assignment","$a = b",1) do |sexp, edges|
    {:b => sexp}
  end

  assert_graph("should generate edges for instance assignment","@a = b",1) do |sexp, edges|
    {:b => sexp}
  end

  assert_graph("should generate edges for const assignment","A = b",1) do |sexp, edges|
    {:b => sexp}
  end

end
