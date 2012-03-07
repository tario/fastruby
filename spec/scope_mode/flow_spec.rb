require "fastruby"
require "sexp"
require "ruby_parser"
require "fastruby/translator/scope_mode_helper"
require "fastruby/builder/reductor"

$parser = RubyParser.new

describe FastRuby::ScopeModeHelper, "scope mode helper" do
  
  def get_scope_mode(tree)
    FastRuby::ScopeModeHelper.get_scope_mode(
      FastRuby::Reductor.new.reduce(
        FastRuby::FastRubySexp.from_sexp(tree)
        )
        )
  end
  
  it "possible read on if after call should return :dag scope mode" do
    get_scope_mode(
      $parser.parse "def foo(a,b,c)
        if (a > 0)
          c
        end
      end"
    ).should be == :dag
  end

  it "possible read on case after call should return :dag scope mode" do
    get_scope_mode(
      $parser.parse "def foo(a,b,c)
        case (a > 0)
          when 0
            c
        end
      end"
    ).should be == :dag
  end

  it "possible read on case (on enum) after call should return :dag scope mode" do
    get_scope_mode(
      $parser.parse "def foo(a,b,c)
        case (a > 0)
          when c
            0
        end
      end"
    ).should be == :dag
  end

  it "for with local read and call should return :dag scope mode" do
    get_scope_mode(
      $parser.parse "def foo(a,b,c)
        for a in b
          foo
          c
        end
      end"
    ).should be == :dag
  end

  it "empty for with local read should return :dag scope mode (because for is a iter call to each with one argument)" do
    get_scope_mode(
      $parser.parse "def foo(a,b,c)
        for a in b
        end
    end"
    ).should be == :dag
  end

  it "case with a when should act as call and local read after case when should return :dag" do
    get_scope_mode(
      $parser.parse "def foo(a,b,c)
        case b
          when c
        end
        a
    end"
    ).should be == :dag
  end
  
  it "case with a when should act as call and local read after case when should return :dag" do
    get_scope_mode(
      $parser.parse "def foo(a,b,c)
        case b
          when c
            a
          else
            c
        end
    end"
    ).should be == :dag
  end  

  it "case with two call (when) after read should return :dag scope" do
    get_scope_mode(
      $parser.parse "def foo(a,b,c)
        case a
          when b # call to a.===(b)
            43
          when c # read of variable c
            439
        end
      end"
    ).should be == :dag
  end


end
