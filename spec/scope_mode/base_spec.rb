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

  it "method without calls should return :linear scope mode" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo(a,b,c) 
        a
      end"
    ).should be == :linear
  end

  it "method with only ONE call should return :linear scope mode" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo(a,b) 
        a+b
      end"
    ).should be == :linear
  end

  it "method with only ONE call and read after call should return :dag scope mode" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo(a,b,c) 
        a+b
        c
      end"
    ).should be == :dag
  end

  it "method with only ONE call and self read after call should return :dag scope mode" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo(a,b,c) 
        a+b
        self
      end"
    ).should be == :dag
  end

  it "method with only ONE call and yield after call should return :dag scope mode" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo(a,b,c) 
        a+b
        yield
      end"
    ).should be == :dag
  end

  it "method with only ONE call and local call after call should return :dag scope mode" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo(a,b,c) 
        a+b
        foo
      end"
    ).should be == :dag
  end

  it "method call AFTER read should return :linear scope" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo(a,b) 
        a=b
        a+b
      end"
    ).should be == :linear
  end

  it "method call AFTER read inside while should return :dag scope" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo(a,b)
        while (true) 
          a=b
          a+b
        end
      end"
    ).should be == :dag
  end
 
end