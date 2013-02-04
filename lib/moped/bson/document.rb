module Moped
  module BSON

    # Represents an entire BSON document.
    class Document < Hash

      class << self

        # Deserialize the raw bytes into a BSON document object.
        #
        # @example Deserialize the raw bytes.
        #   Moped::BSON::Document.deserialize("")
        #
        # @param [ String ] io The raw bytes.
        # @param [ Document ] document The document to load to.
        #
        # @return [ Document ] The document from the raw bytes.
        #
        # @since 1.0.0
        def deserialize(io, document = new)
          __bson_load__(io, document)
        end

        # Serialize a document into raw bytes.
        #
        # @example Serialize the document.
        #   Moped::BSON::Document.serialize(doc, "")
        #
        # @param [ Document ] document The document to serialize.
        # @param [ String ] io The raw bytes to write to.
        #
        # @return [ String ] The raw serialized bytes.
        #
        # @since 1.0.0
        def serialize(document, io = "")
          document.__bson_dump__(io)
        end
      end
    end
  end
end
