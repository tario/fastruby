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

  assert_graph_defn("should have edges for rescue","
    def foo
      begin
          b
        rescue
        end
      end") do |sexp, edges|

    {sexp.find_tree(:rescue)[1] => [sexp.find_tree(:rescue)]}
  end

  assert_graph_defn("should enter the rescue in the body","
    def foo
      a
      begin
          b
        rescue
          c
        end
      end") do |sexp, edges|

    {:a => :b,
      sexp.find_tree(:rescue)[1] => sexp.find_tree(:rescue),
      sexp.find_tree(:rescue) => sexp.find_tree(:block),
      :b => :c,
      :b => sexp.find_tree(:rescue)
    }
  end

  assert_graph_defn("multiple calls on rescue may raise and go to rescue","
    def foo
      begin
          a
          b
          c
        rescue
          d
        end
      end") do |sexp, edges|

    {:a => :d, :b => :d, :c => [:d, sexp.find_tree(:rescue)[1] ], 
      sexp.find_tree(:rescue)[1] => sexp.find_tree(:rescue) }
  end

  assert_graph_defn("multiple calls on ensure may raise and go to rescue","
    def foo
      begin
          a
          b
          c
       ensure
          d
       end
      end") do |sexp, edges|

    {:a => :d, :b => :d, :c => :d, sexp.find_tree(:ensure)[2] => sexp.find_tree(:ensure) }
  end
end
