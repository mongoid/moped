module Moped
  class Connection
    module Socket
      module Connectable

        attr_reader :host, :port

        # Is the socket connection alive?
        #
        # @example Is the socket alive?
        #   socket.alive?
        #
        # @return [ true, false ] If the socket is alive.
        #
        # @since 1.0.0
        def alive?
          if Kernel::select([ self ], nil, [ self ], 0)
            !eof? rescue false
          else
            true
          end
        rescue IOError
          false
        end

        # Bring in the class methods when included.
        #
        # @example Extend the class methods.
        #   Connectable.included(class)
        #
        # @param [ Class ] klass The class including the module.
        #
        # @since 1.3.0
        def self.included(klass)
          klass.send(:extend, ClassMethods)
        end

        # Read from the TCP socket.
        #
        # @param [ Integer ] length The length to read.
        #
        # @return [ Object ] The data.
        #
        # @since 1.2.0
        def read(length)
          check_if_alive!
          handle_socket_errors { super }
        end

        # Write to the socket.
        #
        # @example Write to the socket.
        #   socket.write(data)
        #
        # @param [ Object ] args The data to write.
        #
        # @return [ Integer ] The number of bytes written.
        #
        # @since 1.0.0
        def write(*args)
          check_if_alive!
          handle_socket_errors { super }
        end

        private

        # Before performing a read or write operating, ping the server to check
        # if it is alive.
        #
        # @api private
        #
        # @example Check if the connection is alive.
        #   connectable.check_if_alive!
        #
        # @raise [ ConnectionFailure ] If the connectable is not alive.
        #
        # @since 1.4.0
        def check_if_alive!
          unless alive?
            raise Errors::ConnectionFailure, "Socket connection was closed by remote host"
          end
        end

        # Generate the message for the connection failure based of the system
        # call error, with some added information.
        #
        # @api private
        #
        # @example Generate the error message.
        #   connectable.generate_message(error)
        #
        # @param [ SystemCallError ] error The error.
        #
        # @return [ String ] The error message.
        #
        # @since 1.4.0
        def generate_message(error)
          "#{host}:#{port}: #{error.class.name} (#{error.errno}): #{error.message}"
        end

        # Handle the potential socket errors that can occur.
        #
        # @api private
        #
        # @example Handle the socket errors while executing the block.
        #   handle_socket_errors do
        #     socket.read(128)
        #   end
        #
        # @raise [ Moped::Errors::ConnectionFailure ] If a system call error or
        #   IOError occured which can be retried.
        # @raise [ Moped::Errors::Unrecoverable ] If a system call error occured
        #   which cannot be retried and should be re-raised.
        #
        # @return [ Object ] The result of the yield.
        #
        # @since 1.0.0
        def handle_socket_errors
          yield
        rescue SystemCallError => e
          raise Errors::ConnectionFailure, generate_message(e)
        rescue IOError
          raise Errors::ConnectionFailure, "Connection timed out to Mongo on #{host}:#{port}"
        rescue OpenSSL::SSL::SSLError => e
          raise Errors::ConnectionFailure, "SSL Error '#{e.to_s}' for connection to Mongo on #{host}:#{port}"
        end

        module ClassMethods

          # Connect to the tcp server.
          #
          # @example Connect to the server.
          #   TCPSocket.connect("127.0.0.1", 27017, 30)
          #
          # @param [ String ] host The host to connect to.
          # @param [ Integer ] post The server port.
          # @param [ Integer ] timeout The connection timeout.
          #
          # @return [ TCPSocket ] The socket.
          #
          # @since 1.0.0
          def connect(host, port, timeout)
            begin
              Timeout::timeout(timeout) do
                sock = new(host, port)
                sock.set_encoding('binary')
                timeout_val = [ timeout, 0 ].pack("l_2")
                sock.setsockopt(::Socket::IPPROTO_TCP, ::Socket::TCP_NODELAY, 1)
                sock.setsockopt(::Socket::SOL_SOCKET, ::Socket::SO_RCVTIMEO, timeout_val)
                sock.setsockopt(::Socket::SOL_SOCKET, ::Socket::SO_SNDTIMEO, timeout_val)
                sock
              end
            rescue Timeout::Error
              raise Errors::ConnectionFailure, "Timed out connection to Mongo on #{host}:#{port}"
            end
          end
        end
      end
    end
  end
end
