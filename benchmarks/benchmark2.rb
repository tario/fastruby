require "rubygems"
require "fastruby"

class X
  def foo
		yield
	end
end

class Y
  def bar(x)
	  i = 1000000
			
		lvar_type(i,Fixnum)
			
	  ret = 0
		while i > 0
			x.foo do
			end
		  i = i - 1
		end
		0
	end
end

x = X.new
y = Y.new

require 'benchmark'

Benchmark::bm(20) do |b|
	b.report("ruby") do
		y.bar(x)
	end

  X.optimize(:foo)
  Y.optimize(:bar)
  X.build([X],:foo)
  Y.build([Y,X],:bar)

	b.report("fastruby") do
		y.bar(x)
	end
end
