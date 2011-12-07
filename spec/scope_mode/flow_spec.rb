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

end