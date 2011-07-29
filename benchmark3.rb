require "fastruby"

class X
	fastruby "
		def foo
			yield(1,2,3)
		end
	"
end

class Y
	fastruby "
		def bar(x)
			i = 1000000
			
			lvar_type(i,Fixnum)
			
			ret = 0
			while i > 0
				x.foo do |a,b,c|
				end
				  i = i - 1
			end
			0
		end

	"
end

class X2
	def foo
		yield
	end
end

class Y2
		def bar(x)
			i = 1000000
			
			ret = 0
			while i > 0
				x.foo do
				  i = i - 1
				end
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