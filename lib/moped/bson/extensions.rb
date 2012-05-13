# encoding: utf-8

require "moped/bson/extensions/array"
require "moped/bson/extensions/boolean"
require "moped/bson/extensions/false_class"
require "moped/bson/extensions/float"
require "moped/bson/extensions/hash"
require "moped/bson/extensions/integer"
require "moped/bson/extensions/nil_class"
require "moped/bson/extensions/regexp"
require "moped/bson/extensions/string"
require "moped/bson/extensions/symbol"
require "moped/bson/extensions/time"
require "moped/bson/extensions/true_class"

module Moped

  # @private
  class ::Array
    extend  BSON::Extensions::Array::ClassMethods
    include BSON::Extensions::Array
  end

  # @private
  class ::FalseClass
    extend  BSON::Extensions::Boolean::ClassMethods
    include BSON::Extensions::FalseClass
  end

  # @private
  class ::Float
    extend  BSON::Extensions::Float::ClassMethods
    include BSON::Extensions::Float
  end

  # @private
  class ::Hash
    extend  BSON::Extensions::Hash::ClassMethods
    include BSON::Extensions::Hash
  end

  # @private
  class ::Integer
    extend  BSON::Extensions::Integer::ClassMethods
    include BSON::Extensions::Integer
  end

  # @private
  class ::NilClass
    extend  BSON::Extensions::NilClass::ClassMethods
    include BSON::Extensions::NilClass
  end

  # @private
  class ::Regexp
    extend  BSON::Extensions::Regexp::ClassMethods
    include BSON::Extensions::Regexp
  end

  # @private
  class ::String
    extend  BSON::Extensions::String::ClassMethods
    include BSON::Extensions::String
  end

  # @private
  class ::Symbol
    extend  BSON::Extensions::Symbol::ClassMethods
    include BSON::Extensions::Symbol
  end

  # @private
  class ::Time
    extend  BSON::Extensions::Time::ClassMethods
    include BSON::Extensions::Time
  end

  # @private
  class ::TrueClass
    extend  BSON::Extensions::Boolean::ClassMethods
    include BSON::Extensions::TrueClass
  end
end
