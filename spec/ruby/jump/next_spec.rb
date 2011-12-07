require "fastruby"

describe FastRuby, "fastruby" do
  it "should next on block throught multiple frames" do
   fastruby "
      class ::PX1
		attr_accessor :a,:b

	   def bar
	     yield
	   end

        def foo
          bar do
    			begin
    				begin
    					next 72
    				ensure
    					@a = 1
    				end
    			ensure
    					@b = 2
    			end

    			87
		     end
        end
      end
    "
    px1= ::PX1.new
    px1.foo.should be == 72
    px1.a.should be == 1
    px1.b.should be == 2

  end
end