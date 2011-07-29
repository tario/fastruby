  require "fastruby"
  
  class X
    fastruby '
    def foo(a)
      a.to_s + "_"
    end
    '
  end
  
  p X.new.foo(9) 
  