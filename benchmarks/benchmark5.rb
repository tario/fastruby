require "rubygems"
require "fastruby"

class X
	fastruby "
		def bar
		end
	"
	
	fastruby "
		def foo
			yield(self)
		end
	"
end

class Y
	fastruby "
		def bar(x)
			i = 1000000
			
			lvar_type(i,Fixnum)
	
			x2 = 0
			ret = 0
			while i > 0
				x.foo do |x2|
					x2.bar
				end
				  i = i - 1
			end
			0
		end

	"
end

class X2
	def bar
	end
	
	def foo
		yield(self)
	end
end

class Y2
		def bar(x)
			i = 1000000
			
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
y2 = Y2.new
x2 = X2.new

Y.build([Y,X],:bar) 

require 'benchmark'

Benchmark::bm(20) do |b|
	b.report("fastruby") do
		y.bar(x)
	end

	b.report("ruby") do
		y2.bar(x2)
	end
end
