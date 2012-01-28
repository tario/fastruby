require "fastruby"
require "fastruby/reductor/reductor"
require "fastruby/sexp_extension"
require "ruby_parser"

describe FastRuby, "fastruby" do
  
  def self.test_normal_tree(code)
    unmodified_tree = FastRuby::FastRubySexp.from_sexp RubyParser.new.parse code
    it "tree for source #{code} should not be changed by reductor" do
      obtained_tree = FastRuby::Reductor.new.reduce unmodified_tree
      obtained_tree.should be == unmodified_tree
    end
  end
   
  it "should reduce for statements into each calls" do
   reductor = FastRuby::Reductor.new
   
   original_tree = fs(:for, fs(:call, nil, :b, fs(:arglist)), fs(:lasgn, :a), fs(:call, nil, :c, fs(:arglist)))
   expected_tree = fs(:iter, fs(:call, fs(:call, nil, :b, fs(:arglist)), :each, fs(:arglist)), fs(:lasgn, :a), fs(:call, nil, :c, fs(:arglist)))
   obtained_tree = reductor.reduce original_tree
   
   obtained_tree.should be == expected_tree
  end
 
  test_normal_tree "a.foo(b)"
  test_normal_tree "if (x); y; else; z; end"
  
  it "should reduce call statements into if arrays" do
   reductor = FastRuby::Reductor.new
   
   original_tree = fs(:case, 
      fs(:call, nil, :a, fs(:arglist)), 
      fs(:when, fs(:array, fs(:call, nil, :b, fs(:arglist))), fs(:call, nil, :c, fs(:arglist))), 
      nil)

   obtained_tree = reductor.reduce original_tree
   
   obtained_tree.node_type.should be == :block
   obtained_tree[1].node_type.should be == :lasgn
   obtained_tree[1].last.should be == s(:call, nil, :a, s(:arglist)).to_fastruby_sexp
   obtained_tree[2].node_type.should be == :if
   obtained_tree[2][1].node_type.should be == :or
   obtained_tree[2][2].should be == original_tree.find_tree(:when).last
  end
end