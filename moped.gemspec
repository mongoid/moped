# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

Gem::Specification.new do |s|
  s.name        = "moped"
  s.version     = "0.1"
  s.authors     = ["Bernerd Schaefer"]
  s.email       = ["bj.schaefer@gmail.com"]
  s.homepage    = ""
  s.summary     = ""
  s.description = s.summary

  s.add_dependency "crutches-bson"
  s.add_dependency "crutches-protocol"

  s.files = Dir.glob("lib/**/*") + %w(README.md)
  s.require_path = "lib"
end
