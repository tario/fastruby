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
module Inline
class C
	attr_reader :inc
	
	  def module_name
      unless defined? @module_name then
        module_name = if @mod.name
           @mod.name.gsub('::','__')
         else
           rand(1000000000000000).to_s
         end
        md5 = Digest::MD5.new
        @sig.keys.sort_by { |x| x.to_s }.each { |m| md5 << m.to_s }
        @module_name = "Inline_#{module_name}_#{md5}"
      end
      @module_name
	  end
end
end

