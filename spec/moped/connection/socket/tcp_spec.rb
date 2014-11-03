require 'spec_helper'
require 'moped/connection/socket/tcp'

describe Moped::Connection::Socket::TCP do
  it "raises Moped::Errors::ConnectionFailure if no response within timeout" do
    Timeout::timeout(10) do
      expect {
        # this test relies on the mongo protocol expecting the client
        # to speak first
        socket = described_class.connect('127.0.0.1', 27017, 2)
        socket.read(100)
      }.to raise_exception Moped::Errors::ConnectionFailure
    end
  end
end
