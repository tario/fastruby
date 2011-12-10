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

  it "method call AFTER read should return :linear scope" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo(a,b) 
        a=b
        a+b
      end"
    ).should be == :linear
  end
  
  it "empty if should return :linear scope mode" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo(a,b,c)
        if (a)
        end
      end"
    ).should be == :linear
  end
  it "iter call with empty block should return linear" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo
        bar do
        end
      end"
    ).should be == :linear
  end
  
  it "return of simple call should return :linear" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo(a,b)
      return a+b
      end"
    ).should be == :linear
  end

  it "call on if body and read on condition should return :linear (no read after call risk)" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo(a,b)
        if a
          b.foo
        end
      end"
    ).should be == :linear
  end  

  it "call on if body and read on else body should return :linear (no read after call risk)" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo(a,b)
        if true
          b
        else
          b.foo
        end
      end"
    ).should be == :linear
  end  

end
