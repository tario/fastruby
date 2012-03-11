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
    def +(b)
      if b._class == Fixnum
        _static{LONG2NUM(FIX2LONG(self)+FIX2LONG(b))}
      elsif b._class == Bignum
        _static{rb_big_plus(b,self)}
      elsif b._class == Float
        _static{DBL2NUM(FIX2LONG(self) + RFLOAT_VALUE(b))}
      else
        _static{rb_num_coerce_bin(self, b, '+')}
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
        _static{rb_num_coerce_bin(self, b, '-')}
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
        _static{rb_num_coerce_relop(self, y, '>')}
      end
    end
    
    def <(y)
      if y._class == Fixnum
        _static{FIX2LONG(self)<FIX2LONG2(y) ? true: false }
      elsif y._class == Bignum
        _static{FIX2INT(rb_big_cmp(rb_int2big(FIX2LONG(self)), y)) < 0 ? true : false}
      elsif y._class == Float
        _static{FIX2LONG(self) < RFLOAT_VALUE(y) ? true : false}
      else
        _static{rb_num_coerce_relop(self, y, '<')}
      end
    end    
  end
end