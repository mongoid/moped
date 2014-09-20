module Moped
  module ShellFormatPatch
    module Regexp
      def to_mongo_shell
        UnsafeJSONString.new(inspect)
      end

      def as_json_with_mongo_shell(*args)
        if args.first && args.first[:mongo_shell_format]
          to_mongo_shell
        else
          as_json_without_mongo_shell(*args)
        end
      end

      def self.included(base)
        base.class_eval do
          alias_method :as_json_without_mongo_shell, :as_json
          alias_method :as_json, :as_json_with_mongo_shell
        end
      end
    end
  end
end

::Regexp.send(:include, Moped::ShellFormatPatch::Regexp)