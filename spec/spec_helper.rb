require "java" if RUBY_PLATFORM == "java"
require "bundler"
Bundler.require

$:.unshift((Pathname(__FILE__).dirname.parent + "lib").to_s)

require "moped"

require "support/mock_connection"
