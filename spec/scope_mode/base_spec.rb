require "fastruby"
require "sexp"
require "ruby_parser"
require "fastruby/translator/scope_mode_helper"

$parser = RubyParser.new

describe FastRuby::ScopeModeHelper, "scope mode helper" do
  it "empty method should return :linear scope mode" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo(); end"
    ).should be == :linear
  end

end