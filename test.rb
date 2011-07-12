require "rubygems"
require "fastruby"

class X
	fastruby "
		def foo(a,b)
			a[0..3] = b[0..3]
			return nil
		end
	"
end

a = "test"
b = "ruby"

X.new.foo(a,b)

print a,"\n"