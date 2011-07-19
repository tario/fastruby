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

    def generate(src, options={})
      options = {:expand_types=>options} unless Hash === options

      expand_types = options[:expand_types]
      singleton = options[:singleton]
      result = self.strip_comments(src)

      signature = parse_signature(src, !expand_types)
      function_name = signature['name']
      method_name = options[:method_name]
      method_name ||= test_to_normal function_name
      return_type = signature['return']
      arity = options[:arity] || signature['arity']

      raise ArgumentError, "too many arguments" if arity > MAGIC_ARITY_THRESHOLD

      if expand_types then
        prefix = "static VALUE #{function_name}("
        if arity <= MAGIC_ARITY then
          prefix += "int argc, VALUE *argv, VALUE self"
        else
          prefix += "VALUE self"
          prefix += signature['args'].map { |arg, type| ", VALUE _#{arg}"}.join
        end
        prefix += ") {\n"
        prefix += signature['args'].map { |arg, type|
          "  #{type} #{arg} = #{ruby2c(type)}(_#{arg});\n"
        }.join

        # replace the function signature (hopefully) with new sig (prefix)
        result.sub!(/[^;\/\"\>]+#{function_name}\s*\([^\{]+\{/, "\n" + prefix)
        result.sub!(/\A\n/, '') # strip off the \n in front in case we added it
        unless return_type == "void" then
          raise SyntaxError, "Couldn't find return statement for #{function_name}" unless
            result =~ /return/
        else
          result.sub!(/\s*\}\s*\Z/, "\nreturn Qnil;\n}")
        end
      else
        prefix = "static #{return_type} #{function_name}("
        result.sub!(/[^;\/\"\>]+#{function_name}\s*\(/, prefix)
        result.sub!(/\A\n/, '') # strip off the \n in front in case we added it
      end

      delta = if result =~ /\A(static.*?\{)/m then
                $1.split(/\n/).size
              else
                warn "WAR\NING: Can't find signature in #{result.inspect}\n" unless $TESTING
                0
              end

      file, line = caller[1].split(/:/)
      result = "# line #{line.to_i + delta} \"#{file}\"\n" + result unless $DEBUG and not $TESTING

      @src << result
      @sig[function_name] = [arity,singleton,method_name]

      return result if $TESTING
    end # def generate

end
end

