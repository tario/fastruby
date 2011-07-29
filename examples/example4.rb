  require "fastruby"
  
  class X
    fastruby '
    def foo
      lvar_type(i, Fixnum)
      i = 100
      
      while (i > 0)
	    i = i - 1
      end
      nil
    end
    '
  end

  X.new.foo