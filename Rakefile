require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'
require "rspec/core/rake_task"

spec = Gem::Specification.new do |s|
  s.name = 'fastruby'
  s.version = '0.0.22'
  s.author = 'Dario Seminara'
  s.email = 'robertodarioseminara@gmail.com'
  s.platform = Gem::Platform::RUBY
  s.summary = 'fast execution of ruby code'
  s.homepage = "http://github.com/tario/fastruby"
  s.add_dependency "RubyInline", "= 3.11.0"
  s.add_dependency "ruby_parser", ">= 2.0.6"
  s.add_dependency "define_method_handler", ">= 0.0.6"
  s.add_dependency "method_source", ">= 0.6.7"
  s.add_dependency "ruby2ruby", ">= 1.3.1"
  s.has_rdoc = true
  s.extra_rdoc_files = [ 'README.rdoc' ]
  s.extensions = FileList["ext/**/extconf.rb"].to_a
#  s.rdoc_options << '--main' << 'README.rdoc'
  s.files = Dir.glob("{benchmarks,examples,lib,spec}/**/*") + Dir.glob("ext/**/*.inl")+ Dir.glob("ext/**/*.c") + Dir.glob("ext/**/*.h") + Dir.glob("ext/**/extconf.rb") +
    [ 'LICENSE', 'AUTHORS', 'README.rdoc', 'Rakefile', 'TODO', 'CHANGELOG' ]
end

desc 'Run tests'

RSpec::Core::RakeTask.new("test:units") do |t|
  t.pattern= 'spec/**/*.rb'
end

desc 'Generate RDoc'
Rake::RDocTask.new :rdoc do |rd|
  rd.rdoc_dir = 'doc'
  rd.rdoc_files.add 'lib', 'README.rdoc'
  rd.main = 'README.rdoc'
end

desc 'Build Gem'
Rake::GemPackageTask.new spec do |pkg|
  pkg.need_tar = true
end

desc 'Clean up'
task :clean => [ :clobber_rdoc, :clobber_package ]

desc 'Clean up'
task :clobber => [ :clean ]
