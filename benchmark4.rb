require "fastruby"

class Y
	fastruby "
		def bar
			i = 1000000
			
			lvar_type(i,Fixnum)
			
			ret = 0
			while i > 0
			  $a = 9
			  i = i - 1
			end
			0
		end

	"
end

class Y2
		def bar
			i = 1000000
			
			ret = 0
			while i > 0
			  $a = 9
			  i = i - 1
			end
			0
		end
end


class Y_
	fastruby "
		def bar
			i = 1000000
			
			lvar_type(i,Fixnum)
			
			ret = 0
			while i > 0
			  i = i - 1
			end
			0
		end

	"
end

class Y2_
		def bar
			i = 1000000
			
			ret = 0
			while i > 0
			  i = i - 1
			end
			0
		end
end


y = Y.new
y2 = Y2.new
y_ = Y_.new
y2_ = Y2_.new

Y.build([Y],:bar)
Y_.build([Y_],:bar)

require 'benchmark'

Benchmark::bm(20) do |b|

	b.report("fastruby") do
		y.bar
	end

	b.report("ruby") do
		y2.bar
	end
	
	b.report("lfastruby") do
		y_.bar
	end

	b.report("lruby") do
		y2_.bar
	end
	
end
