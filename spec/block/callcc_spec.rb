require "fastruby"
if RUBY_VERSION =~ /^1\.9/
require "continuation"
end

describe FastRuby, "fastruby" do
  class ::N1
    fastruby "
      def bar(cc)
        cc.call(75)
      end

      def foo
        callcc do |cc|
          bar(cc)
        end
      end
    "
  end

  it "should execute callcc on fastruby" do
    ::N1.new.foo.should be == 75
  end

  class ::N2
   def bar(cc)
     cc.call(76)
   end

    fastruby "
      def foo
        callcc do |cc|
          bar(cc)
        end
      end
    "
  end

  it "should execute callcc from ruby" do
    ::N2.new.foo.should be == 76
  end

  class ::N3
    fastruby "
      def foo(n_)
        n = n_

        val = 0
        cc = nil

        x = callcc{|c| cc = c; nil}

        val = val + x if x
        n = n - 1

        cc.call(n) if n > 0

        val
      end
    "
  end

  it "should execute callcc from ruby using local variables" do
    ::N3.new.foo(4).should be == 6
  end

  class ::N4
    fastruby "
      def foo(n_)
        $n = n_

        $val = 0
        c = 0


        x = callcc{|c| $cc_n4 = c; nil}

        $val = $val + x if x
        $n = $n - 1

        $cc_n4.call($n) if $n > 0

        $val
      end
    "
  end

  it "should execute callcc from ruby using global variables" do
    ::N4.new.foo(4).should be == 6
  end

  class ::N5
    fastruby "
      def foo(n_)
        $n = n_

        $val = 0
        c = 0
        u = nil

        x = callcc{|c| $cc_n4 = c; u = 44; nil}

        $val = $val + x if x
        $n = $n - 1

        $cc_n4.call($n) if $n > 0

        u
      end
    "
  end

  it "should execute callcc loops and preserve local variables" do
    ::N5.new.foo(4).should be == 44
  end

  class ::N6
    fastruby "
    
      def bar
        a = 5555
        
        callcc do |cc|
          $cc = cc
        end
        
        a
      end
      
      def another_method(n)
        a = 9999
	    another_method(n-1) if n>0
      end
    
      def foo
        
        $called = nil
        
        ret = bar
        another_method(200)
        
        unless $called
          $called = 1
          $cc.call
        end
        
        ret
      end
    "
  end

  it "should execute callcc loops and preserve local variables when another method is called after callcc" do
    ::N6.new.foo.should be == 5555
  end
  
  
  it "shouldn't raise LocalJumpError from proc being called on callcc de-initialized stack" do
    
fastruby <<ENDSTR

class ::N7
  def foo
    val = nil
    
    pr = Proc.new do 
      return val
    end
    
    val = callcc do |cc|
      $cc = cc
    end
    
    pr.call
  end

  def bar
    ret = foo

    if ret.instance_of? Continuation
      ret.call(4)
    else
      $cc.call(ret-1) if ret > 0
    end
  end
end

ENDSTR
    
    
    n7 = ::N7.new
    lambda {
      n7.bar
    }.should_not raise_error(LocalJumpError)
  end
  
  it "should raise LocalJumpError from proc defined on abandoned stack after Continuation#call" do
  
fastruby <<ENDSTR
class ::N8
  def bar
    ret = callcc do |cc|
      $cc_n8 = cc
    end
    
    if ret == 9
      $pr_n8.call
    end
    
    ret
  end
  
  def foo3
    $cc_n8.call(9)
  end
  
  def foo2
    $pr_n8 = Proc.new do
      return
    end
    
    foo3
  end
  
  def foo
    return if bar == 9
    foo2
  end
end
ENDSTR

    n8 = ::N8.new
    lambda {
      n8.foo
    }.should raise_error(LocalJumpError)
  end  
end
