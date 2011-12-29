module EdgesHelper

  class Edges < Array
    def initialize(sexp); @sexp = sexp; end

    def to_sexp(obj, &blk)
      if obj.instance_of? Symbol
        blk.call @sexp.find_tree{|st| st.node_type == :call and st[2] == obj}
      elsif obj.instance_of? Array
        obj.each do |element|
          to_sexp(element,&blk)
        end
      else
        blk.call obj
      end
    end

    def tr_edges(hash)
      hash.each do |k,v|
        to_sexp(k) do |a|
          to_sexp(v) do |b|
            yield(a,b)
          end
        end
      end
    end
  end

  def get_defn_edges(code)
    sexp = FastRuby::FastRubySexp.parse(code)

    edges = Edges.new(sexp)
    sexp[3].edges.each do |tree_orig, tree_dest|
      edges << [tree_orig, tree_dest]
    end

    yield(sexp, edges)
  end  

  def get_edges(code)
    sexp = FastRuby::FastRubySexp.parse(code)

    edges = Edges.new(sexp)
    sexp.edges.each do |tree_orig, tree_dest|
      edges << [tree_orig, tree_dest]
    end

    yield(sexp, edges)
  end

  module KlassLevelHelper
    def assert_graph(assert_name, code, node_count = nil)
      it assert_name do
        get_edges(code) do |sexp, edges|
          condition_tree = sexp[1]
          execution_tree = sexp[2]

          if node_count
            edges.count.should be == node_count
          end

          edges.tr_edges yield(sexp,edges) do |a,b|
            edges.should include([a,b])
          end
        end
      end
    end

    def assert_graph_defn(assert_name, code, node_count = nil)
      it assert_name do
        get_defn_edges(code) do |sexp, edges|
          condition_tree = sexp[1]
          execution_tree = sexp[2]

          if node_count
            edges.count.should be == node_count
          end

          edges.tr_edges yield(sexp,edges) do |a,b|
            edges.should include([a,b])
          end
        end
      end
    end
  end

  def self.included(klass)
    klass.extend KlassLevelHelper
  end
end

