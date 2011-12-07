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

  it "iter call with empty block should return linear" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo
        bar do
        end
      end"
    ).should be == :linear
  end
  
  it "iter call with block accessing locals should return dag" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo(a)
        bar do
          a
        end
      end"
    ).should be == :dag
  end
  
  it "iter call with block doing yield should return dag" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo(a)
        bar do
          yield
        end
      end"
    ).should be == :dag
  end  
  
  it "iter call with block with arguments should return dag" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo(a)
        bar do |x|
        end
      end"
    ).should be == :dag
  end  

  it "iter call with block writing local variable should return dag" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo(a)
        bar do
          a = 87
        end
      end"
    ).should be == :dag
  end

  it "two iter call, one empty and the second with yield should return dag" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "def foo(a)
        bar do
        end
        
        bar do
          yield
        end
      end"
    ).should be == :dag
  end
  
  it "lambda with yield must return :dag" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "          def foo
            lambda {
              yield
            }
          end
        "
    ).should be == :dag
  end  

  it "method with return from inside block return :dag" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "    def bar
            foo do
              return 9
            end
          end
        "
    ).should be == :dag
  end  
end