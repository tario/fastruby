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
require "fastruby/exceptions"
require "fastruby/object"
require "fastruby/exceptions"
require "fastruby/custom_require"
require "fastruby/set_tree"
require "base64"

class Object
  def self.decode64(value)
    Base64.decode64(value)
  end
end

module FastRuby
  VERSION = "0.0.17" unless defined? FastRuby::VERSION
end
