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

  assert_graph_defn("should enter the ensure in the body","
    def foo
      a
      begin
          b
        ensure
          c
        end
      end") do |sexp, edges|

    {:a => :b,
      :b => :c}
  end


  assert_graph_defn("should link declaration of exceptions on rescue","
    def foo
      begin
          a
        rescue b => c
          d
        end
      end") do |sexp, edges|

    {:a => :b,
      :b => sexp.find_tree(:gvar), 
      sexp.find_tree(:gvar) => sexp.find_tree(:lasgn),
      sexp.find_tree(:lasgn) => :d     
       }
  end

  assert_graph_defn("should link multiple declaration of exceptions on rescue","
    def foo
      begin
          a
        rescue b, d => e
          f
        end
      end") do |sexp, edges|

    array_tree = sexp.find_tree(:array)

    {:a => :b,
      :b => [sexp.find_tree(:gvar), :d], 
      sexp.find_tree(:gvar) => sexp.find_tree(:lasgn),
      sexp.find_tree(:lasgn) => :f,
      :d => sexp.find_tree(:gvar)
       }
  end
  
  assert_graph_defn("should link trees on rescue without execution body","
               def foo
                  begin
                  rescue Exception
                    return a
                  end
                end") do |sexp,edges|  
     {}
    
  end

  assert_graph_defn("should link trees on rescue without execution body and else","
               def foo
                  begin
                  rescue Exception
                    return a
                  else
                    return b
                  end
                end") do |sexp,edges|  
    {}
    
  end

  assert_graph_defn("should link call previous to rescue when execution body of rescue is empty","
               def foo
                  z
                  begin
                  rescue Exception
                    return a
                  else
                    return b
                  end
                end") do |sexp,edges|  
    {:z => sexp.find_tree(:rescue) }
    
  end

end
