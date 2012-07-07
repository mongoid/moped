require "rspec/core/rake_task"

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "moped/version"

task :gem => :build
task :build do
  system "gem build moped.gemspec"
end

task :install => :build do
  system "sudo gem install moped-#{Moped::VERSION}.gem"
end

task :release => :build do
  system "git tag -a v#{Moped::VERSION} -m 'Tagging #{Moped::VERSION}'"
  system "git push --tags"
  system "gem push moped-#{Moped::VERSION}.gem"
  system "rm moped-#{Moped::VERSION}.gem"
end

RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = "spec/**/*_spec.rb"
end

task :default => :spec
