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

  assert_graph("should generate edges for if with or condition","if (a or b); c; else; d; end",6) do |sexp, edges|
    {:a => :b, :b => sexp.find_tree(:or), sexp.find_tree(:or) => [:c,:d], :c => sexp, :d => sexp }
  end
end
