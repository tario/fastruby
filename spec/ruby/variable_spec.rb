require "fastruby"

describe FastRuby, "fastruby" do

  class ::U1
    fastruby "
      def foo
        $au1 = 88
      end
    "
  end

  it "should write global variables" do
    ::U1.new.foo
    $au1.should be == 88
  end

  class ::U2
    fastruby "
      def foo
        $au2
      end
    "
  end

  it "should read global variables" do
    $au2 = 88
    ::U2.new.foo.should be == 88
  end

  class ::U3
    attr_accessor :au3

    fastruby "
      def foo
        @au3 = 88
      end
    "
  end

  it "should write instance variables" do
    u3 = ::U3.new
    u3.foo
    u3.au3.should be == 88
  end

  class ::U4
    attr_accessor :au4

    fastruby "
      def foo
        @au4
      end
    "
  end

  it "should read instance variables" do
    u4 = ::U4.new
    u4.au4 = 88
    u4.foo.should be == 88
  end

  class ::U5
    fastruby "
      def foo
        U5C = 11
      end
    "
  end

  it "should write constants" do
    ::U5.new.foo

    U5C.should be == 11
  end

  class ::U6
    fastruby "
      def foo
        U6C
      end
    "
  end

  it "should read constants" do
    ::U6C = 11
    ::U6.new.foo.should be == 11
  end


  class ::U7
    class U71
      fastruby "
        def foo
          U7C = 11
        end
      "
    end
  end

  it "should write nested constants" do
    ::U7::U71.new.foo
    ::U7::U71::U7C.should be == 11

    lambda {
    ::U7::U7C.should be == 11
    }.should_not raise_error
  end

  class ::U8
    class U81
      fastruby "
        def foo
          U8C
        end
      "
    end
  end
  it "should read  nested constants" do
    ::U8::U81::U8C = 11
    ::U8::U81.new.foo.should be == 11
  end

  class ::U9
    fastruby "
      def foo
        ::U9C
      end
    "
  end
  it "should read constant with colon3" do
    ::U9C = 21
    ::U9.new.foo.should be == 21
  end

  it "should write constant with colon3" do
    class ::U10
      fastruby "
        ::U10C = 51
        def foo
        end
      "
    end
    ::U10.new.foo
    ::U10C.should be == 51
  end

  class ::U11
    fastruby "
      def foo
        ::U11::U11C
      end
    "
  end
  it "should read constant with colon3 and colon2" do
    ::U11::U11C = 21
    ::U11.new.foo.should be == 21
  end

  it "should write constant with colon3 and colon2" do
    class ::U12
      fastruby "
        ::U12::U12C = 51
        def foo
        end
      "
    end
    ::U12.new.foo
    ::U12::U12C.should be == 51
  end

  it "should call defined? to undefined local variable and return nil" do
    class ::U13
      fastruby "
        def foo
          defined? wowowowo
        end
      "
    end
    ::U13.new.foo.should be == nil
  end

  it "should call defined? to undefined constant and return nil" do
    class ::U16
      fastruby "
        def foo
          defined? Wowowowow
        end
      "
    end
    ::U16.new.foo.should be == nil
  end

  $u_class_number = 30
  def self.test_defined(code,title,defined_name)
    it "should call defined? to defined #{title} and return '#{defined_name}" do
      classname = "::U"+$u_class_number.to_s

      $u_class_number = $u_class_number + 1
      code = "def foo; #{code}; end"
      eval("class #{classname}
        fastruby #{code.inspect}
      end")
      eval(classname).new.foo.should be == defined_name
    end
  end

  def self.test_defined_block(code,title,defined_name)
    it "should call defined? to defined #{title} and return '#{defined_name}'" do
      classname = "::U"+$u_class_number.to_s

      $u_class_number = $u_class_number + 1
      code = "def foo; #{code}; end"
      eval("class #{classname}
        fastruby #{code.inspect}
      end")
      eval(classname).new.foo{}.should be == defined_name
    end
  end

  test_defined "@a =17; defined? @a", "instance variable", "instance-variable"

  $a = 9
  test_defined "defined? $a", "global variable", "global-variable"
  test_defined "a = 17; defined? a", "local variable", "local-variable"
  test_defined "defined? Fixnum", "constant", "constant"
  test_defined_block "defined? yield", "yield", "yield"
  test_defined "defined? true", "true", "true"
  test_defined "defined? false", "false", "false"
  test_defined "defined? nil", "nil", "nil"
  test_defined "defined? self", "self", "self"
  test_defined "defined? print", "method", "method"
  test_defined "defined?(if 0; 4; end)", "expression", "expression"

  ["a", "$a", "@a", "@@a", "A"].each do |var|
     test_defined "defined? #{var}=0", "#{var} assignment", "assignment"
   end

  it "should read class variable" do
    class ::U17

      def self.foo(a)
        @@a = a
      end

      fastruby "
        def foo
          @@a
        end
      "
    end
    ::U17.foo(31)
    ::U17.new.foo.should be === 31
  end

  it "should write class variable" do
    class ::U18

      def self.foo
        @@a
      end

      fastruby "
        def foo(a)
          @@a = a
        end
      "
    end
    ::U18.new.foo(71)
    ::U18.foo.should be == 71
  end


end