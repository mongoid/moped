require "spec_helper"

describe Moped::Protocol::Commands::Authenticate do
  let(:username) { "username" }
  let(:password) { "password" }
  let(:nonce) { "7268c504683936e1" }
  let(:auth) do
    described_class.new "admin", username, password, nonce
  end

  describe "#initialize" do
    it "sets the full collection name" do
      auth.full_collection_name.should eq "admin.$cmd"
    end

    it "sets the selector" do
      auth.selector.should eq auth.build_auth_command(username, password, nonce)
    end
  end

  describe "#digest" do
    it "returns the authentication key" do
      auth.digest(username, password, nonce).should eq Digest::MD5.hexdigest(
        nonce + username + Digest::MD5.hexdigest(username + ":mongo:" + password)
      )
    end
  end

  describe "#build_auth_command" do
    let(:auth) { described_class.allocate }
    let(:auth_command) do
      auth.build_auth_command username, password, nonce
    end

    it "sets authenticate to 1" do
      auth_command[:authenticate].should eq 1
    end

    it "sets the user" do
      auth_command[:user].should eq username
    end

    it "sets the nonce" do
      auth_command[:nonce].should eq nonce
    end

    it "sets the key" do
      auth_command[:key].should eq auth.digest(username, password, nonce)
    end
  end

end
