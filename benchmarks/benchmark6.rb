require "rubygems"
require "fastruby"

def lvar_type(*x); end

class X
	def foo
		"65535".to_i
	end
end

class Y
	def bar(x)
		i = 1000000
		lvar_type(i,Fixnum)
	
		while i > 0
			x.foo
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
