require "rubygems"
require "fastruby"

class X
	fastruby "
		def foo(a,b)
			return b
		end
	"

#  inline :C  do |builder|
#  builder.c "VALUE foo( VALUE a,VALUE b  ) {
 #       return 4;

 #     }
#"
 # end
end

x = X.new
print x.foo(1,243),"\n"
