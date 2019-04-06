module Moped
  module Protocol
    module Commands
      class ScramAuthenticate
        SCRAM_SHA_1_MECHANISM = 'SCRAM-SHA-1'.freeze
        CLIENT_CONTINUE_MESSAGE = { saslContinue: 1 }.freeze
        CLIENT_FIRST_MESSAGE = { saslStart: 1, autoAuthorize: 1 }.freeze
        CLIENT_KEY = 'Client Key'.freeze
        ID = 'conversationId'.freeze
        ITERATIONS = /i=(\d+)/.freeze
        MIN_ITER_COUNT = 4096
        PAYLOAD = 'payload'.freeze
        RNONCE = /r=([^,]*)/.freeze
        SALT = /s=([^,]*)/.freeze
        SERVER_KEY = 'Server Key'.freeze
        VERIFIER = /v=([^,]*)/.freeze

        attr_reader \
          :database,
          :username,
          :password,
          :nonce,
          :result

        def initialize(database, username, password)
          @database = database
          @username = username
          @password = password
        end

        def start(result)
          @nonce = result[Protocol::NONCE]
          Protocol::Command.new(database, {
            saslStart: 1,
            autoAuthorize: 1,
            payload: client_first_message,
            mechanism: SCRAM_SHA_1_MECHANISM
          })
        end

        def continue(result)
          validate_first_message!(result)
          salted_password

          Protocol::Command.new(database, {
            saslContinue: 1,
            payload: client_final_message,
            conversationId: result[ID]
          })
        end

        def finalize(result)
          Protocol::Command.new(
            database,
            CLIENT_CONTINUE_MESSAGE.merge(
              payload: client_empty_message,
              conversationId: result[ID]
            )
          )
        end

        private

        def client_empty_message
          BSON::Binary.new(:md5, '')
        end

        def hmac(data, key)
          OpenSSL::HMAC.digest(digest, data, key)
        end

        def xor(first, second)
          first.bytes.zip(second.bytes).map{ |(a,b)| (a ^ b).chr }.join('')
        end

        def validate_first_message!(result)
          validate!(result)
          raise Errors::InvalidNonce.new(nonce, rnonce) unless rnonce.start_with?(nonce)
        end

        def client_key
          @client_key ||= hmac(salted_password, CLIENT_KEY)
        end

        def client_proof(key, signature)
          @client_proof ||= Base64.strict_encode64(xor(key, signature))
        end

        def client_final
          @client_final ||= client_proof(client_key, client_signature(stored_key(client_key), auth_message))
        end

        def auth_message
          @auth_message ||= "#{first_bare},#{result[PAYLOAD].data},#{without_proof}"
        end

        def stored_key(key)
          h(key)
        end

        def h(string)
          digest.digest(string)
        end

        def client_signature(key, message)
          @client_signature ||= hmac(key, message)
        end

        def without_proof
          @without_proof ||= "c=biws,r=#{rnonce}"
        end

        def client_final_message
          BSON::Binary.new(:md5, "#{without_proof},p=#{client_final}")
        end

        def rnonce
          @rnonce ||= payload_data.match(RNONCE)[1]
        end

        def validate!(result)
          if result[Protocol::OK] != 1
            raise Errors::AuthenticationFailure.new(
              'scram.start',
              { "err" => "Invalid result ok = #{result[Protocol::OK]}" }
            )
          end
          @result = result
        end

        def payload_data
          result[PAYLOAD].data
        end

        def iterations
          @iterations ||= payload_data.match(ITERATIONS)[1].to_i.tap do |i|
            if i < MIN_ITER_COUNT
              raise Errors::InsufficientIterationCount.new(
                Errors::InsufficientIterationCount.message(MIN_ITER_COUNT, i))
            end
          end
        end

        def hi(data)
          OpenSSL::PKCS5.pbkdf2_hmac_sha1(
            data,
            Base64.strict_decode64(salt),
            iterations,
            digest.size
          )
        end

        def salt
          @salt ||= payload_data.match(SALT)[1]
        end

        def digest
          @digest ||= OpenSSL::Digest::SHA1.new.freeze
        end

        def salted_password
          hi(hashed_password)
        end

        def hashed_password
          unless password
            raise Errors::MissingPassword
          end
          @hashed_password ||= Digest::MD5.hexdigest("#{username}:mongo:#{password}").encode('utf-8')
        end

        def client_first_message
          BSON::Binary.new(:md5, "n,,#{first_bare}")
        end

        def first_bare
          @first_bare ||= "n=#{username.encode('utf-8').gsub('=','=3D').gsub(',','=2C')},r=#{nonce}"
        end
      end
    end
  end
end
