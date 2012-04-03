=begin

This file is part of the fastruby project, http://github.com/tario/fastruby

Copyright (c) 2011 Roberto Dario Seminara <robertodarioseminara@gmail.com>

fastruby is free software: you can redistribute it and/or modify
it under the terms of the gnu general public license as published by
the free software foundation, either version 3 of the license, or
(at your option) any later version.

fastruby is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.  see the
gnu general public license for more details.

you should have received a copy of the gnu general public license
along with fastruby.  if not, see <http://www.gnu.org/licenses/>.

=end
require "define_method_handler"
 
module FastRuby
  class LvarType
    define_method_handler(:process) {|tree|
        if @process_defn_disabled
          tree
        else
          old = @process_defn_disabled
          @process_defn_disabled = true
          begin
            tree.map &method(:process)
          ensure
            @process_defn_disabled = old
          end
        end
        
        tree
      }.condition{|tree| tree.node_type == :defn or tree.node_type == :defs}
      
  end
end
