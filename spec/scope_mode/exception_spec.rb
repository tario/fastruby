require "fastruby"
require "sexp"
require "ruby_parser"
require "fastruby/translator/scope_mode_helper"

$parser = RubyParser.new

describe FastRuby::ScopeModeHelper, "scope mode helper" do
  it "method with read on begin body, call on rescue body and retry should return :dag scope mode" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo(a,b,c) 
        begin
          b
        rescue
          a.foo
          retry
        end
      end"
    ).should be == :dag
  end
  
  it "method with read on begin body and retry should return :dag scope mode" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo(a,b,c) 
        begin
          nil.bar(b)
        rescue
          retry
        end
      end"
    ).should be == :dag
  end
  
end
