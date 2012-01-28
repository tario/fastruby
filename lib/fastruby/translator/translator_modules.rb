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
require "singleton"

module FastRuby
  class TranslatorModules
    include Singleton    
   
    attr_accessor :modls
    
    def initialize
      @modls = Array.new
    end
    
    def register_translator_module(modl)
      @modls << modl  
    end
    
    def each_under(dir)
      Dir.glob(dir + "/*.rb") do |x|
        yield x
      end
    end

    def load_under(dir)
      each_under(dir, &method(:require))
    end
  end
end

module Kernel
    def register_translator_module(modl)
      FastRuby::TranslatorModules.instance.register_translator_module(modl)  
    end
end
