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
require "sha1"
require "fileutils"

module FastRuby
  class Cache
    include FileUtils

    def initialize(base_path)
      @base_path = base_path

      begin
        Dir.mkdir(@base_path)
      rescue Errno::EEXIST
      end
    end

    def hash_snippet(snippet)
      SHA1.hexdigest(snippet)
    end

    def insert(hash,path)
      dest = @base_path + "/#{hash}/"

      begin
        Dir.mkdir(dest)
      rescue Errno::EEXIST
      end

      cp_r path, dest
    end

    def retrieve(hash)
      dest = @base_path + "/#{hash}/"

      Dir[dest + "*.so"]
    end
  end
end
