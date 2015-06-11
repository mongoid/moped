# encoding: utf-8
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require "moped/version"

Gem::Specification.new do |s|
  s.name        = "moped"
  s.version     = Moped::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = [ "Durran Jordan", "Bernerd Schaefer"]
  s.email       = [ "durran@gmail.com" ]
  s.homepage    = "http://mongoid.org/en/moped"
  s.summary     = "A MongoDB driver for Ruby."
  s.description = s.summary
  s.files = Dir.glob("lib/**/*") + %w(CHANGELOG.md LICENSE README.md)
  s.require_path = "lib"
  s.add_dependency("bson", ["~> 3.0"])
  s.add_dependency("connection_pool", ["~> 2.0"])
  s.add_dependency("optionable", ["~> 0.2.0"])
end
