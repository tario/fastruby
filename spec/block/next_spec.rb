require "fastruby"

describe FastRuby, "fastruby" do
  class ::W1
    fastruby "
      def foo(ary)
        sum = 0
        ary.each do |a|
          next if a == 2
          sum = sum + a
        end

        sum
      end
    "
  end

  it "should execute basic test iterating an array" do
    ::W1.new.foo([1,2,3]).should be == 4
  end
end