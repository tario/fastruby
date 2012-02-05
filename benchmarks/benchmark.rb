require "rubygems"
require "fastruby"

class X
  def foo(a,b)
		return a+b
	end
end

class Y
	def bar(x)
		i = 1000000
		
  	lvar_type(i,Fixnum)
			
		ret = 0
		while i > 0
			ret = x.foo(i,i)
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

  X.optimize(:foo)
  Y.optimize(:bar)
  X.build([X,Fixnum,Fixnum],:foo)
  Y.build([Y,X],:bar)

	b.report("fastruby") do
		y.bar(x)
	end
end
