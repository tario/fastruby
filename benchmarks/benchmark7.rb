require "rubygems"
require "fastruby"

class X
	fastruby "
		def factorial(n)
			if n > 1
				n * factorial((n-1).infer(Fixnum))
			else
				1
			end
		end
	"
end

class Y
	fastruby "
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

	"
end

class X2
	def factorial(n)
		if n > 1
			n * factorial(n-1)
		else
			1
		end
	end
end

class Y2
		def bar(x)
			i = 100000
			
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
