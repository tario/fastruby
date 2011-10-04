require "fastruby"

describe FastRuby, "fastruby" do

  it "should accept else with rescue" do

    random_name = "::L11_1"
    fastruby "
          class #{random_name}
              def foo
                begin
                  raise Exception
                rescue Exception
                  return 111
                else
                  return 222
                end
              end
          end
           "

    l = eval(random_name).new
    l.foo.should be == 111
   end

  it "should accept else with rescue, when no exception is raised" do

      random_name = "::L12_1"
      fastruby "
            class #{random_name}
                def foo
                  begin
                  rescue Exception
                    return 111
                  else
                    return 222
                  end
                end
            end
             "

      l = eval(random_name).new
      l.foo.should be == 222
     end

    it "should accept else with rescue, when no exception is raised and begin has body" do

      random_name = "::L13_1"
      fastruby "
            class #{random_name}
                def foo
                  begin
                    a = 77
                  rescue Exception
                    return 111
                  else
                    return 222
                  end
                end
            end
             "

    l = eval(random_name).new
    l.foo.should be == 222
   end

    def self.argumentless_rescue(exceptionname)
        fastruby "
          class ::L15_#{exceptionname}
            def foo
              begin
                raise #{exceptionname}
              rescue
              end
            end
          end
        "

      it "should argumentless rescue catch #{exceptionname}" do
        l15 = eval("::L15_#{exceptionname}").new
        lambda {
          l15.foo
        }.should_not raise_exception
      end
    end

    argumentless_rescue("RuntimeError")

  it "should read exception into local" do
    fastruby "
      class ::LLX1
        def foo
          begin
            raise Exception,'message'
          rescue Exception => a
          end

          a
        end
      end
    "

    llx1 = ::LLX1.new
    llx1.foo.message.should be == "message"
  end

  it "should read exception into local with traps of two exceptions" do
    fastruby "
      class ::LLX2
        def foo
          begin
            raise RuntimeError,'message2'
          rescue LocalJumpError, RuntimeError => b
          end

          b
        end
      end
    "

    llx2 = ::LLX2.new
    llx2.foo.message.should be == "message2"
  end


end