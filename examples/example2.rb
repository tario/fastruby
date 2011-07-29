require "fastruby"
  
  class X
    fastruby '
    def foo(a,b)
      a+b
    end
    '
  end
  
  X.build([X,String,String] , :foo)
  
  p X.new.foo("fast", "ruby") # will use the prebuilded method
  p X.new.foo(["fast"], ["ruby"]) # will build foo for X,Array,Array signature and then execute it
