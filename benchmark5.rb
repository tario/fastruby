require "fastruby"

class Y
	
	fastruby "
		def foo
		end
	"
	
	
	fastruby "
		def bar
			i = 1000000
			
			lvar_type(i,Fixnum)
			
			ret = 0
			while i > 0
			  foo
			  i = i - 1
			end
			0
		end

	"
end

class Y2
	
	def foo
	end
		
		def bar
			i = 1000000
			
			ret = 0
			while i > 0
			 foo
			  i = i - 1
			end
			0
		end
end


y = Y.new
y2 = Y2.new

Y.build([Y],:bar)
Y.build([Y],:foo)

require 'benchmark'

Benchmark::bm(20) do |b|

	b.report("fastruby") do
		y.bar
	end

	b.report("ruby") do
		y2.bar
	end
end
