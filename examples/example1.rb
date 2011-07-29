  require "fastruby"
  
  class X
    fastruby '
    def foo
	  print "hello world\n"
    end
   '
  end
  
  X.new.foo
  