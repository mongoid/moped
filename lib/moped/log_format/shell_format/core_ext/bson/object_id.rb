module Moped
  module ShellFormatPatch
    module ObjectId
      def to_mongo_shell(*args)
        UnsafeJSONString.new(%Q{ObjectId("#{to_s}")})
      end

      def as_json_with_mongo_shell(*args)
        if args.first && args.first[:mongo_shell_format]
          to_mongo_shell
        else
          as_json_without_mongo_shell(*args)
        end
      end

      def to_json_with_mongo_shell(*args)
        if args.first && args.first[:mongo_shell_format]
          to_mongo_shell
        else
          to_json_without_mongo_shell(*args)
        end
      end

      def self.included(base)
        base.class_eval do
          if defined? ActiveSupport
            alias_method :as_json_without_mongo_shell, :as_json
            alias_method :as_json, :as_json_with_mongo_shell
          else
            alias_method :to_json_without_mongo_shell, :to_json
            alias_method :to_json, :to_json_with_mongo_shell
          end
        end
      end
    end
  end
end

::BSON::ObjectId.send(:include, Moped::ShellFormatPatch::ObjectId)