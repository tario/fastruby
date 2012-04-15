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
  fastruby(:fastruby_only => true, :skip_reduce => true) do
    def times
      unless block_given?
        return _static{rb_enumeratorize(self, _dynamic{:times}, inline_c("0"), inline_c("0") ) }
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
    
    def upto(x)
      unless block_given?
        return _static{rb_enumeratorize(self, _dynamic{:upto}, inline_c("1"), c_address_of(x)) }
      end
      
      if self._class == Fixnum
        if x._class == Fixnum
          i = self
          while _static{FIX2LONG(i) <= FIX2LONG(x)}
            yield(i)
            i = _static{LONG2FIX(FIX2LONG(i)+1)}
          end
      
          return self  
        end
      end
      
      i = self
      while i <= x
        yield(i)
        i = i + 1
      end
      
      self
    end

    def downto(x)
      unless block_given?
        return _static{rb_enumeratorize(self, _dynamic{:downto}, inline_c("1"), c_address_of(x)) }
      end
      
      if self._class == Fixnum
        if x._class == Fixnum
          i = self
          while _static{FIX2LONG(i) >= FIX2LONG(x)}
            yield(i)
            i = _static{LONG2FIX(FIX2LONG(i)-1)}
          end
      
          return self  
        end
      end
      
      i = self
      while i >= x
        yield(i)
        i = i - 1
      end
      
      self
    end

  end
end
