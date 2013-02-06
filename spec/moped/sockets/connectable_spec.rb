require "spec_helper"

describe Moped::Sockets::Connectable do

  describe "#handle_socket_errors" do

    let(:object) do
      Class.new do
        include Moped::Sockets::Connectable
        def host; "127.0.0.1"; end
        def port; 27017; end
      end.new
    end

    context "when a Errno::ECONNREFUSED is raised" do

      it "re-raises a ConnectionFailure" do
        expect{
          object.send(:handle_socket_errors) { raise Errno::ECONNREFUSED }
        }.to raise_error(
          Moped::Errors::ConnectionFailure,
          "127.0.0.1:27017: Errno::ECONNREFUSED (61): Connection refused"
        )
      end
    end

    context "when a Errno::EHOSTUNREACH is raised" do

      it "re-raises a ConnectionFailure" do
        expect{
          object.send(:handle_socket_errors) { raise Errno::EHOSTUNREACH }
        }.to raise_error(
          Moped::Errors::ConnectionFailure,
          "127.0.0.1:27017: Errno::EHOSTUNREACH (65): No route to host"
        )
      end
    end

    context "when a Errno::EPIPE is raised" do

      it "re-raises a ConnectionFailure" do
        expect{
          object.send(:handle_socket_errors) { raise Errno::EPIPE }
        }.to raise_error(
          Moped::Errors::ConnectionFailure,
          "127.0.0.1:27017: Errno::EPIPE (32): Broken pipe"
        )
      end
    end

    context "when a Errno::ECONNRESET is raised" do

      it "re-raises a ConnectionFailure" do
        expect{
          object.send(:handle_socket_errors) { raise Errno::ECONNRESET }
        }.to raise_error(
          Moped::Errors::ConnectionFailure,
          "127.0.0.1:27017: Errno::ECONNRESET (54): Connection reset by peer"
        )
      end
    end

    context "when a Errno::ETIMEDOUT is raised" do

      it "re-raises a ConnectionFailure" do
        expect{
          object.send(:handle_socket_errors) { raise Errno::ETIMEDOUT }
        }.to raise_error(
          Moped::Errors::ConnectionFailure,
          "127.0.0.1:27017: Errno::ETIMEDOUT (60): Operation timed out"
        )
      end
    end
  end
end
