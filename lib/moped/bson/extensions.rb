require "moped/bson/extensions/array"
require "moped/bson/extensions/boolean"
require "moped/bson/extensions/false_class"
require "moped/bson/extensions/float"
require "moped/bson/extensions/hash"
require "moped/bson/extensions/integer"
require "moped/bson/extensions/nil_class"
require "moped/bson/extensions/object"
require "moped/bson/extensions/regexp"
require "moped/bson/extensions/string"
require "moped/bson/extensions/symbol"
require "moped/bson/extensions/time"
require "moped/bson/extensions/true_class"

module Moped
  module BSON
    module Extensions

      # @private
      class ::Array
        extend  Moped::BSON::Extensions::Array::ClassMethods
        include Moped::BSON::Extensions::Array
      end

      # @private
      class ::FalseClass
        extend  Moped::BSON::Extensions::Boolean::ClassMethods
        include Moped::BSON::Extensions::FalseClass
      end

      # @private
      class ::Float
        extend  Moped::BSON::Extensions::Float::ClassMethods
        include Moped::BSON::Extensions::Float
      end

      # @private
      class ::Hash
        extend  Moped::BSON::Extensions::Hash::ClassMethods
        include Moped::BSON::Extensions::Hash
      end

      # @private
      class ::Integer
        extend  Moped::BSON::Extensions::Integer::ClassMethods
        include Moped::BSON::Extensions::Integer
      end

      # @private
      class ::NilClass
        extend  Moped::BSON::Extensions::NilClass::ClassMethods
        include Moped::BSON::Extensions::NilClass
      end

      # @private
      class ::Object
        include Moped::BSON::Extensions::Object
      end

      # @private
      class ::Regexp
        extend  Moped::BSON::Extensions::Regexp::ClassMethods
        include Moped::BSON::Extensions::Regexp
      end

      # @private
      class ::String
        extend  Moped::BSON::Extensions::String::ClassMethods
        include Moped::BSON::Extensions::String
      end

      # @private
      class ::Symbol
        extend  Moped::BSON::Extensions::Symbol::ClassMethods
        include Moped::BSON::Extensions::Symbol
      end

      # @private
      class ::Time
        extend  Moped::BSON::Extensions::Time::ClassMethods
        include Moped::BSON::Extensions::Time
      end

      # @private
      class ::TrueClass
        extend  Moped::BSON::Extensions::Boolean::ClassMethods
        include Moped::BSON::Extensions::TrueClass
      end
    end
  end
end
