require "fastruby"

describe FastRuby, "fastruby retry statement" do
  class ::WG1
    attr_reader :a, :b

    def initialize
      @a = 0
      @b = 0
    end

    fastruby "
      def bar
        @a = @a + 1

        yield(1)
        yield(2)
        yield(3)
      ensure
        @b = @b + 1
      end

      def foo
        sum = 0
        bar do |x|
          sum = sum + 1
          retry if x == 3 and sum < 30
        end

        sum
      end
    "
  end

  it "should execute basic retry" do
    wg1 = ::WG1.new
    wg1.foo.should be == 30
    wg1.a.should be == 10
    wg1.b.should be == 10
  end


  class ::WG2
    attr_reader :a, :b

    def initialize
      @a = 0
      @b = 0
    end

    fastruby "
      def bar(x)
        @a = @a + 1

        yield(1)
        yield(2)
        yield(3)
      ensure
        @b = @b + 1
      end

      def foo
        sum = 0
        bar(0) do |x|
          sum = sum + 1
          retry if x == 3 and sum < 30
        end

        sum
      end
    "
  end

  it "should work with a method more arguments than zero" do
    wg2 = ::WG2.new
    wg2.foo.should be == 30
    wg2.a.should be == 10
    wg2.b.should be == 10
  end

  class ::WG3
    fastruby "
      def foo
        sum = 0
        begin
          sum = sum + 1
          raise RuntimeError
        rescue RuntimeError
          retry if sum < 10
        end

        sum
      end
    "
  end

  it "should work with rescue" do
    ::WG3.new.foo.should be == 10
  end

end