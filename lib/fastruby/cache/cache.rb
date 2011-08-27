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

  def self.cache
    @@cache = FastRuby::Cache.new(ENV['HOME']+"/.fastruby/") unless defined? @@cache
    @@cache
  end

  class Cache
    include FileUtils

    def initialize(base_path)
      @base_path = base_path
      create_dir_if_not_exists(@base_path)
    end

    def hash_snippet(snippet, addition)
      SHA1.hexdigest(snippet + addition)
    end

    def insert(hash,path)
      create_hash_dir(hash)
      dest = hash_dir(hash)
      cp_r path, dest
    end

    def retrieve(hash)
      create_hash_dir(hash)
      dest = hash_dir(hash)
      Dir[dest + "*.so"]
    end

private

    def hash_dir(hash)
      @base_path + "/#{hash[0..1]}/#{hash[2..-1]}/"
    end

    def create_hash_dir(hash)
      create_dir_if_not_exists(@base_path + "/#{hash[0..1]}/")
      create_dir_if_not_exists(@base_path + "/#{hash[0..1]}/#{hash[2..-1]}/")
    end

    def create_dir_if_not_exists(dest)
      begin
        Dir.mkdir(dest)
      rescue Errno::EEXIST
      end
    end
  end
end
