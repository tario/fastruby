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
module FastRuby
  class << self
    attr_accessor :fastruby_script_path
    attr_accessor :fastruby_load_path
  end

  FastRuby.fastruby_script_path = File.expand_path(__FILE__)
  FastRuby.fastruby_load_path = File.expand_path(File.dirname(__FILE__))
end
