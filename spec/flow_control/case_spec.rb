require "fastruby"

describe FastRuby, "case statement" do
  class ::O1
    fastruby '
      def foo(a)
        case a
        when 1
          2
        when 2
          10
        when 3
          9
        else
          11
        end
      end
    '
  end

  it "should execute" do
    o1 = ::O1.new
    o1.foo(1).should be == 2
    o1.foo(2).should be == 10
    o1.foo(3).should be == 9
    o1.foo(4).should be == 11
  end

  class ::O2
    fastruby '
      def foo(a)
        case a
          when 34
            32
        end
      end
    '
  end

  it "should return nil when any option is matched" do
    o2 = ::O2.new
    o2.foo(1).should be == nil
  end

  class ::O3
    fastruby '
      def foo(a,b,c,d)
        case a
          when b
            32
          when c
            15
          when d
            16
        end
      end
    '
  end

  it "should call === on each comparison" do
    obj = Object.new

    b = ""
    c = ""
    d = ""

    b.should_receive(:===).with(obj)
    c.should_receive(:===).with(obj)
    d.should_receive(:===).with(obj)

    o3 = ::O3.new
    o3.foo(obj,b,c,d).should be == nil
  end

  class ::O4
    fastruby '
      def foo(a)
        case a
        when 1,3
          2
        when 2,4
          10
        end
      end
    '
  end

  it "should execute case with arrays in when" do
    o4 = ::O4.new
    o4.foo(1).should be == 2
    o4.foo(2).should be == 10
    o4.foo(3).should be == 2
    o4.foo(4).should be == 10
  end

  class ::O5
    fastruby '
      def foo(a)
        case a
        when /a/
          2
        else
          nil
        end
      end
    '
  end

  it "should execute case with regular expressions" do
    o5 = ::O5.new
    o5.foo("aaa").should be == 2
  end


  class ::O6
    fastruby '
      def foo(a)
        case a
        when 5..10
          2
        else
          nil
        end
      end
    '
  end

  it "should execute case with ranges" do
    o6 = ::O6.new

    (5..10).each do |i|
      o6.foo(i).should be == 2
    end
  end

end
