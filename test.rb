require "rubygems"
require "fastruby"


class X
	fastruby '
		def foo(a,b)
			10.times do
				print "ao\n"
			end
		end
	'
end

$array = Array

class Array
	fastruby '
		def fast_map
			s = self.size
			ary = $array.new(size)
			
			(0..s-1).each do |i|
				print i,"\n"
			end
			
			ary
		end
	'
end

a = "test"
b = "ruby"

#X.new.foo(a,b)

p [1,2,3].fast_map,"\n"