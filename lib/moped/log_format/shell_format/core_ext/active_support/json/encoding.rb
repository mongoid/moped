module Moped
  module ShellFormatPatch
    module JSONGemEncoder
      def jsonify_with_mongo_shell(value)
        case value
        when UnsafeJSONString
          value
        else
          jsonify_without_mongo_shell(value)
        end
      end

      def self.included(base)
        base.class_eval do
          alias_method :jsonify_without_mongo_shell, :jsonify
          alias_method :jsonify, :jsonify_with_mongo_shell
        end
      end
    end
  end
end

if defined? ::ActiveSupport
  ::ActiveSupport::JSON::Encoding::JSONGemEncoder.send(:include, Moped::ShellFormatPatch::JSONGemEncoder)
end