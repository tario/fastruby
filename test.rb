require "rubygems"
require "fastruby"

class X
	fastruby "
		def foo(a,b)
			return 4
		end
	"
end

x = X.new
print x.foo,"\n"