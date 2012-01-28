require "fastruby"
require "fastruby/reductor/reductor"

describe FastRuby, "fastruby" do
  it "should reduce for statements into each calls" do
   reductor = FastRuby::Reductor.new
   
   original_tree = s(:for, s(:call, nil, :b, s(:arglist)), s(:lasgn, :a), s(:call, nil, :c, s(:arglist))).to_fastruby_sexp
   expected_tree = s(:iter, s(:call, s(:call, nil, :b, s(:arglist)), :each, s(:arglist)), s(:lasgn, :a), s(:call, nil, :c, s(:arglist))).to_fastruby_sexp
   obtained_tree = reductor.reduce original_tree
   
   obtained_tree.should be == expected_tree
  end

end