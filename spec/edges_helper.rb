module EdgesHelper

  class Edges < Array
    def initialize(sexp); @sexp = sexp; end

    def to_sexp(obj)
      if obj.instance_of? Symbol
        yield @sexp.find_tree{|st| st.node_type == :call and st[2] == obj}
      elsif obj.instance_of? Array
        obj.each do |element|
          to_sexp(element) do |x|
            yield x
          end
        end
      else
        yield obj
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
end

