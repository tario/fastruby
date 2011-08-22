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
module Kernel

  alias original_require require

  def fastruby_require(path)
    if path =~ /\.so$/
      require(path)
    else
      FastRuby.logger.info "trying to load '#{path}'"

      complete_path = path + (path =~ /\.rb$/ ? "" : ".rb")

      $LOAD_PATH.each do |load_path|
        begin
          source = nil
          File.open(load_path + "/" + complete_path) do |file|
            source = file.read
          end

          FastRuby.logger.info "loading '#{load_path + "/" + complete_path}'"

          fastruby source
          return true
        rescue Errno::ENOENT
        end
      end

      raise LoadError
    end
  end
end
