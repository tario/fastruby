require "fastruby"
require "fastruby/sexp_extension"
require "sexp"
require "ruby_parser"
require "edges_helper"

describe FastRuby::FastRubySexp, "FastRubySexp" do
  include EdgesHelper

  it "should have two edges for if" do
    get_edges("if a; b; else; c; end") do |sexp, edges|
      edges.size.should be == 4
      edges.should include([sexp[1],sexp[2]]) # true block after condition
      edges.should include([sexp[1],sexp[3]]) # false block after condition
      edges.should include([sexp[2],sexp]) # if after true block
      edges.should include([sexp[3],sexp]) # if after false block
    end
  end

  it "should have only one edge for if without else" do
    get_edges("if a; b; end") do |sexp, edges|
      edges.size.should be == 3
      edges.should include([sexp[1],sexp[2]]) # true block after condition
      edges.should include([sexp[2],sexp]) # if after true block
      edges.should include([sexp[1],sexp]) # if after condition
    end
  end

  it "should have only one edge for unless" do
    get_edges("unless a; b; end") do |sexp, edges|
      edges.size.should be == 3

      edges.should include([sexp[1],sexp[3]]) # false block after condition
      edges.should include([sexp[3],sexp]) # if after false block
      edges.should include([sexp[1],sexp]) # if after condition
    end
  end

  it "should connect with the first node" do
    get_edges("if a; b.foo(x); end") do |sexp, edges|
      call_tree = sexp[2]
      edges.should include([sexp[1],call_tree[1]]) # call recv after condition
    end
  end

  it "should connect previous call on block with condition of next if" do
    get_edges("foo; if a; b; end") do |sexp, edges|
      edges.should include([sexp[1],sexp[2][1]]) # if condition after call
    end
  end

  it "should create circular connection from while nodes" do
    get_edges("while(a); foo; bar; end") do |sexp, edges|
      condition_tree = sexp[1]
      execution_tree = sexp[2]

      edges.size.should be == 5

      edges.should include([condition_tree,execution_tree[1]])
      edges.should include([execution_tree,condition_tree])
      edges.should include([condition_tree,sexp])
    end
  end

  it "should connect break inside while nodes with while" do
    get_edges("while(a); foo; break; bar; end") do |sexp, edges|
      condition_tree = sexp[1]
      execution_tree = sexp[2]

      edges.size.should be == 7

      edges.should include([condition_tree,execution_tree[1]])
      edges.should include([execution_tree,condition_tree])
      edges.should include([condition_tree,sexp])
      edges.should include([execution_tree[2],sexp])
    end
  end

  it "should connect previous call on block with condition of next while" do
    get_edges("foo; while(a); b; end") do |sexp, edges|
      edges.should include([sexp[1],sexp[2][1]]) # if condition after call
    end
  end

  it "should connect previous call on block with condition of next while" do
    get_edges("
      case a
      when b
        c
      when d
        e
      else
        f
      end
      ") do |sexp, edges|

      variable_node = sexp[1]
      when_node_1 = sexp[2]
      when_node_1_condition = when_node_1[1][1]
      when_node_1_body = when_node_1[2]
      when_node_2 = sexp[3]
      when_node_2_condition = when_node_2[1][1]
      when_node_2_body = when_node_2[2]
      else_body = sexp.last

      edges.should include([variable_node,when_node_1_condition])
      edges.should include([when_node_1_condition,when_node_1_body])
      edges.should include([when_node_1_condition,when_node_2_condition])
      edges.should include([when_node_1_body,sexp])
      edges.should include([when_node_2_condition,when_node_2_body])
      edges.should include([when_node_2_condition,else_body])
      edges.should include([when_node_2_body,sexp])
      edges.should include([else_body,sexp])
      
    end
  end

  it "should connect nodes of multiple options of when" do
    get_edges("
      case a
      when b,c
        d
      else
        e
      end
      ") do |sexp, edges|

      edges.tr_edges :a => :b, 
                              :b => :c, :b => :d,
                              :c => :d, :c => :e,
                              :d => sexp,
                              :e => sexp do |a,b|
        self.should include([a,b])
      end
    end
  end
end
