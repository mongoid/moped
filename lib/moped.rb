# encoding: utf-8
require "logger"
require "stringio"
require "monitor"
require "timeout"
require 'resolv'
require "bson"
require "optionable"
require "moped/errors"
require "moped/indexes"
require "moped/loggable"
require "moped/uri"
require "moped/protocol"
require "moped/session"
require "moped/version"

module Moped
  extend Loggable
end
