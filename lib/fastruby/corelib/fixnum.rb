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
require "fastruby/sexp_extension"

class Fixnum
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

    if RUBY_VERSION =~ /^1\\.9/
      def +(b)
        if b._class == Fixnum
          _static{LONG2NUM(FIX2LONG(self)+FIX2LONG(b))}
        elsif b._class == Bignum
          _static{rb_big_plus(b,self)}
        elsif b._class == Float
          _static{DBL2NUM(FIX2LONG(self) + RFLOAT_VALUE(b))}
        else
          _static{rb_num_coerce_bin(self, b, inline_c("'+'"))}
        end
      end

      def -(b)
        if b._class == Fixnum
          _static{LONG2NUM(FIX2LONG(self)-FIX2LONG(b))}
        elsif b._class == Bignum
          _static{rb_big_minus(rb_int2big(FIX2LONG(self)),b)}
        elsif b._class == Float
          _static{DBL2NUM(FIX2LONG(self) - RFLOAT_VALUE(b))}
        else
          _static{rb_num_coerce_bin(self, b, inline_c("'-'"))}
        end
      end

      def >(y)
        if y._class == Fixnum
          _static{FIX2LONG(self)>FIX2LONG(y) ? true: false }
        elsif y._class == Bignum
          _static{FIX2INT(rb_big_cmp(rb_int2big(FIX2LONG(self)), y)) > 0 ? true : false}
        elsif y._class == Float
          _static{FIX2LONG(self) > RFLOAT_VALUE(y) ? true : false}
        else
          _static{rb_num_coerce_relop(self, y, inline_c("'>'"))}
        end
      end
      
      def <(y)
        if y._class == Fixnum
          _static{FIX2LONG(self)<FIX2LONG(y) ? true: false }
        elsif y._class == Bignum
          _static{FIX2INT(rb_big_cmp(rb_int2big(FIX2LONG(self)), y)) < 0 ? true : false}
        elsif y._class == Float
          _static{FIX2LONG(self) < RFLOAT_VALUE(y) ? true : false}
        else
          _static{rb_num_coerce_relop(self, y, inline_c("'<'"))}
        end
      end    
    end
  end
end
