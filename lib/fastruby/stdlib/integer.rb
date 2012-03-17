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
class Integer
  fastruby(:skip_reduce => true) do
    def times
      unless block_given?
        if self._class == Fixnum
          return (0.._static{LONG2FIX(FIX2LONG(self)-1)})
        else
          return (0..self-1)
        end
      end
      
      if self._class == Fixnum
        i = 0
        while _static{FIX2LONG(i) < FIX2LONG(self)}
          yield(i)
          i = _static{LONG2FIX(FIX2LONG(i)+1)}
        end
      else
        i = 0
        while i < self
          yield(i)
          i = i + 1
        end
      end
    end
  end
end
