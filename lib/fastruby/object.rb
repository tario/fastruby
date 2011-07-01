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
require "fastruby/translator"
require "ruby_parser"
require "inline"

# clean rubyinline cache
system("rm -fr #{ENV["HOME"]}/.ruby_inline/*")

class Object
  def self.fastruby(rubycode)
    tree = RubyParser.new.parse rubycode
    context = FastRuby::Context.new

    inline :C  do |builder|
      c_code = context.to_c(tree)
      print c_code,"\n"
      builder.c c_code
    end
  end
end
