require "spec_helper"

describe Moped::Protocol do
  Protocol = Moped::Protocol

  let(:connection) do
    TCPSocket.new("localhost", 27017)
  end

  after do
    connection.close unless connection.closed?
  end

  describe "authentication" do
    context "when nonce is invalid" do
      let(:auth) do
        Protocol::Commands::Authenticate.new :admin, "user", "pass", "fakenonce"
      end

      it "fails" do
        connection.write auth
        reply = Protocol::Reply.deserialize(connection).documents[0]
        reply["ok"].should eq 0.0
      end
    end

    context "when nonce is valid but user doesn't exist" do
      let(:nonce) do
        command = Protocol::Command.new :admin, getnonce: 1
        connection.write command
        Protocol::Reply.deserialize(connection).documents[0]["nonce"]
      end

      let(:auth) do
        Protocol::Commands::Authenticate.new :admin, "user", "pass", nonce
      end

      it "fails" do
        connection.write auth
        reply = Protocol::Reply.deserialize(connection).documents[0]
        reply["ok"].should eq 0.0
      end
    end

    context "when nonce is valid but password is wrong" do
      let(:nonce) do
        command = Protocol::Command.new "moped-protocol-spec", getnonce: 1
        connection.write command
        Protocol::Reply.deserialize(connection).documents[0]["nonce"]
      end

      let(:auth) do
        Protocol::Commands::Authenticate.new "moped-protocol-spec",
          "moped",
          "pass",
          nonce
      end

      before do
        connection.write Protocol::Insert.new(
          "moped-protocol-spec",
          "system.users",
          [{ user: "moped", pwd: Digest::MD5.hexdigest("moped:mongo:password") }]
        )
      end

      it "fails" do
        connection.write auth
        reply = Protocol::Reply.deserialize(connection).documents[0]
        reply["ok"].should eq 0.0
      end
    end

    context "when authentication is valid" do
      let(:nonce) do
        command = Protocol::Command.new "moped-protocol-spec", getnonce: 1
        connection.write command
        Protocol::Reply.deserialize(connection).documents[0]["nonce"]
      end

      let(:auth) do
        Protocol::Commands::Authenticate.new "moped-protocol-spec",
          "moped",
          "password",
          nonce
      end

      before do
        connection.write Protocol::Insert.new(
          "moped-protocol-spec",
          "system.users",
          [{ user: "moped", pwd: Digest::MD5.hexdigest("moped:mongo:password") }]
        )
      end

      it "succeeds" do
        connection.write auth
        reply = Protocol::Reply.deserialize(connection).documents[0]
        reply["ok"].should eq 1.0
      end
    end
  end
end
