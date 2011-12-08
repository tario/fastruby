require "fastruby"
require "sexp"
require "ruby_parser"
require "fastruby/translator/scope_mode_helper"

$parser = RubyParser.new

describe FastRuby::ScopeModeHelper, "scope mode helper" do
  it "empty if should return :linear scope mode" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo(a,b,c)
        if (a)
        end
      end"
    ).should be == :linear
  end

  it "possible read on if after call should return :dag scope mode" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo(a,b,c)
        if (a > 0)
          c
        end
      end"
    ).should be == :dag
  end

  it "possible read on case after call should return :dag scope mode" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo(a,b,c)
        case (a > 0)
          when 0
            c
        end
      end"
    ).should be == :dag
  end

  it "possible read on case (on enum) after call should return :dag scope mode" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo(a,b,c)
        case (a > 0)
          when c
            0
        end
      end"
    ).should be == :dag
  end

  it "for with local read and call should return :dag scope mode" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo(a,b,c)
        for a in b
          foo
          c
        end
      end"
    ).should be == :dag
  end

  it "empty for with local read should return :dag scope mode (because for is a iter call to each with one argument)" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo(a,b,c)
        for a in b
        end
    end"
    ).should be == :dag
  end

end