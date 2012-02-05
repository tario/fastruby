require "rubygems"
require "fastruby"

class X
	def bar
	end
	
  def foo
		yield(self)
	end
end

class Y
	def bar(x)
		i = 1000000
			
		lvar_type(:i,Fixnum)
		lvar_type(:x2,X)
	
		ret = 0
		while i > 0
			x.foo do |x2|
				x2.bar
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

  Y.optimize(:bar) 
  X.optimize(:foo)
  X.optimize(:bar)

  Y.build([Y,X],:bar) 
  X.build([X],:foo)
  X.build([X],:bar)

	b.report("fastruby") do
		y.bar(x)
	end
end
