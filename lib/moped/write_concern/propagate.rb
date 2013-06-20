# encoding: utf-8
module Moped
  module WriteConcern

    # Propagating write concerns piggyback a getlasterror command to any write
    # operation with the necessary options.
    #
    # @since 2.0.0
    class Propagate

      # @!attribute operation
      #   @return [ Hash ] The gle operation.
      attr_reader :operation

      # Initialize the propagating write concern.
      #
      # @example Instantiate the write concern.
      #   Moped::WriteConcern::Propagate.new(w: 3)
      #
      # @param [ Hash ] operation The operation to execute.
      #
      # @since 2.0.0
      def initialize(options)
        @operation = { getlasterror: 1 }.merge!(normalize(options))
      end

      private

      def normalize(options)
        opts = {}
        options.each do |key, value|
          opts[key] = value.is_a?(Symbol) ? value.to_s : value
        end
        opts
      end
    end
  end
end
