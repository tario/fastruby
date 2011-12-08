require "fastruby"
require "sexp"
require "ruby_parser"
require "fastruby/translator/scope_mode_helper"

$parser = RubyParser.new

describe FastRuby::ScopeModeHelper, "scope mode helper" do
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
  
  it "method with self from inside block return :dag" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "    def bar
            foo do
              self
            end
          end
        "
    ).should be == :dag
  end
  
  it "local call from inside block should return :dag" do
    FastRuby::ScopeModeHelper.get_scope_mode(
      $parser.parse "    def bar
            foo do
              print
            end
          end
        "
    ).should be == :dag
  end
  
end