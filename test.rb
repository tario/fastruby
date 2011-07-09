require "rubygems"
require "fastruby"

class X
	fastruby "
		def foo(a,b)
			return a+b
		end
	"
end

class Y
	fastruby "
		def bar(x)
			return x.foo(4,4).infer(Fixnum) + x.foo(5,6)
		end
"
  fastruby "
    def bar_2(x,x2)
      return x.foo(4,4).infer(Fixnum) + x2.foo(5,6)
    end
	"
end

x = X.new
y = Y.new

20.times do
y.bar(x)
end

class Z

def foo(a,b)
  9
end
end

#print y.bar(x),"\n"
#print y.bar(Z.new),"\n"
#print y.bar_2(x,x),"\n"
#print x.foo(5353531,6000000),"\n"
#print x.foo("5353531","6000000"),"\n"
#p x.foo([1],[2,3]),"\n"
