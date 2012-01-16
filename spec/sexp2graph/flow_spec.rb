require "fastruby"
require "fastruby/sexp_extension"
require "sexp"
require "ruby_parser"
require "edges_helper"

describe FastRuby::FastRubySexp, "FastRubySexp" do
  include EdgesHelper

  assert_graph("should have two edges for if","if a; b; else; c; end",4) do |sexp, edges|
    {:a => [:b,:c], :b => sexp, :c => sexp}
  end

  assert_graph("should have only one edge for if without else","if a; b; end",3) do |sexp, edges|
    {:a => [:b,sexp], :b => sexp}      
  end

  assert_graph("should have only one edge for unless","unless a; b; end",3) do |sexp, edges|
   {:a => [:b,sexp], :b => sexp}
  end

  assert_graph("should connect with the first node","if a; b.foo(x); end") do |sexp, edges|
    if_body = sexp.find_tree(:if)[2]
    {:a => :b, :b => :x, :x => if_body, if_body => sexp }
  end

  assert_graph("should connect previous call on block with condition of next if","foo; if a; b; end") do |sexp, edges|
    {:foo => :a }
  end

  assert_graph("should create circular connection from while nodes",
              "while(a); foo; bar; end",5) do |sexp, edges|
    { :a => :foo, sexp.find_tree(:block) => :a, :a => sexp}
  end

  assert_graph("should connect break inside while nodes with while", "while(a); foo; break; bar; end", 7) do |sexp,edges|
    {:a => [:foo,sexp], sexp.find_tree(:break) => sexp, sexp.find_tree(:block) => :a}
  end

  assert_graph("should connect previous call on block with condition of next while",
      "foo; while(a); b; end") do |sexp,edges|
      {:foo => :a }
    
  end

  assert_graph("should create circular connection from until nodes",
              "until(a); foo; bar; end",5) do |sexp, edges|
    { :a => :foo, sexp.find_tree(:block) => :a, :a => sexp}
  end

  assert_graph("should connect break inside until nodes with until", "until(a); foo; break; bar; end", 7) do |sexp,edges|
    {:a => [:foo,sexp], sexp.find_tree(:break) => sexp, sexp.find_tree(:block) => :a}
  end

  assert_graph("should connect previous call on block with condition of next until",
      "foo; until(a); b; end") do |sexp,edges|
      {:foo => :a }
    
  end

  assert_graph("literals, literals everywhere","
      1; 2; 3; 4
      ") do |sexp, edges|

    {}
  end
end
