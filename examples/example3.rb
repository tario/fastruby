  require "fastruby"
  
  class X
    fastruby '
    def foo(a)
      a.to_s.infer(String) + "_"
    end
    '
  end
  
  p X.new.foo(9) 
  