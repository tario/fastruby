require "rubygems"
require "fastruby"

class X
  def factorial(n)
		if n > 1
			n * factorial((n-1).infer(Fixnum))
		else
			1
		end
	end
end

class Y
	def bar(x)
		i = 100000
		
		lvar_type(i,Fixnum)
			
		ret = 0
		while i > 0
			x.factorial(20)
			i = i - 1
  	end
		return ret
	end
end

x = X.new
y = Y.new

require 'benchmark'

Benchmark::bm(20) do |b|
	b.report("ruby") do
		y.bar(x)
	end

  X.optimize(:factorial)
  Y.optimize(:bar)
  X.build([X],:factorial)
  Y.build([Y,X],:bar)

	b.report("fastruby") do
		y.bar(x)
	end
end

