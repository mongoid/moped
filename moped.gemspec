# encoding: utf-8
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require "moped/version"

Gem::Specification.new do |s|
  s.name        = "moped"
  s.version     = Moped::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Bernerd Schaefer"]
  s.email       = ["bj.schaefer@gmail.com"]
  s.homepage    = "http://mongoid.org/moped"
  s.summary     = "A MongoDB driver for Ruby."
  s.description = s.summary

  s.add_development_dependency("rspec", ["~> 2.9"])
  s.add_development_dependency("guard-rspec", ["~> 0.6"])

  s.files = Dir.glob("lib/**/*") + %w(LICENSE README.md)
  s.require_path = "lib"
end
