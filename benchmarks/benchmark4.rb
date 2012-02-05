require "rubygems"
require "fastruby"

class Y
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
end

class Y_
	def bar
		i = 1000000
			
		lvar_type(i,Fixnum)
			
		ret = 0
		while i > 0
		  i = i - 1
		end
		0
	end
end

y = Y.new
y_ = Y_.new
require 'benchmark'

Benchmark::bm(20) do |b|

	b.report("ruby") do
		y.bar
	end

	b.report("lruby") do
		y_.bar
	end

  Y.optimize(:bar)
  Y_.optimize(:bar)
  Y.build([Y],:bar)
  Y_.build([Y_],:bar)

	b.report("fastruby") do
		y.bar
	end

	b.report("lfastruby") do
		y_.bar
	end
end
