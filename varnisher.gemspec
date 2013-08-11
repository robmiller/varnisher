$:.push File.expand_path("../lib", __FILE__)
require "varnisher/version"

Gem::Specification.new do |s|
  s.name = "varnisher"
  s.version = Varnisher::VERSION
  s.date = "2013-08-11"

  s.summary = "Helpful tools for working with Varnish caches"
  s.description = "Some tools that make working with the Varnish HTTP cache easier, including things like doing mass purges of entire domains."

  s.authors = ["Rob Miller"]
  s.email = "rob@bigfish.co.uk"
  s.homepage = "http://github.com/robmiller/varnisher"

  s.license = "MIT"

  s.files = Dir.glob("{bin,lib}/**/*") + %w(LICENSE README.md)
  s.executables = ['varnisher']
  s.require_path = 'lib'

  s.add_runtime_dependency 'hpricot', '~> 0.8.6'
  s.add_runtime_dependency 'parallel', '~> 0.7.1'
end
