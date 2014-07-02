require "spec_helper"

describe Moped::Errors::MongoError do

  describe "#message" do

    context "when an assertionCode is in the details" do

      let(:command) do
        Moped::Protocol::Command.new(:moped_test, "")
      end

      let(:result) do
        { "assertionCode" => 9014, "assertion" => "The map/reduce failed" }
      end

      let(:error) do
        described_class.new(command, result)
      end

      let(:message) do
        error.message
      end

      it "returns the assertion code in the error" do
        message.should include("9014")
      end

      it "returns the assertion message in the error" do
        message.should include("The map/reduce failed")
      end
    end
  end

  describe "#reconfiguring_replica_set?" do

    context "when error code 13435" do

      let(:details) do
        { "code" => 13435 }
      end

      let(:error) do
        Moped::Errors::PotentialReconfiguration.new({}, details)
      end

      it "returns true" do
        error.should be_reconfiguring_replica_set
      end
    end

    context "when error code 10009" do

      let(:details) do
        { "code" => 10009 }
      end

      let(:error) do
        Moped::Errors::PotentialReconfiguration.new({}, details)
      end

      it "returns true" do
        error.should be_reconfiguring_replica_set
      end
    end

    context "when error code 13436" do

      let(:details) do
        { "code" => 13436 }
      end

      let(:error) do
        Moped::Errors::PotentialReconfiguration.new({}, details)
      end

      it "returns true" do
        error.should be_reconfiguring_replica_set
      end
    end

    context "when 'err' is not master" do

      let(:details) do
        { "err" => "not master" }
      end

      let(:error) do
        Moped::Errors::PotentialReconfiguration.new({}, details)
      end

      it "returns true" do
        error.should be_reconfiguring_replica_set
      end
    end

    context "when 'errmsg' is not master" do

      let(:details) do
        { "errmsg" => "not master" }
      end

      let(:error) do
        Moped::Errors::PotentialReconfiguration.new({}, details)
      end

      it "returns true" do
        error.should be_reconfiguring_replica_set
      end
    end

    context "when 'err' contains not master" do

      let(:details) do
        { "errmsg" => "not master or secondary; cannot currently read from this replSet member" }
      end

      let(:error) do
        Moped::Errors::PotentialReconfiguration.new({}, details)
      end

      it "returns true" do
        error.should be_reconfiguring_replica_set
      end
    end

    context "when errors are not matching not master" do

      let(:details) do
        { "errmsg" => "unauthorized" }
      end

      let(:error) do
        Moped::Errors::PotentialReconfiguration.new({}, details)
      end

      it "returns false" do
        error.should_not be_reconfiguring_replica_set
      end
    end
  end

  describe "#connection_failure?" do
    context "when 'err' contains could not get last error from shard" do

      let(:details) do
        { "errmsg" => "could not get last error from shard rs0/localhost:37017,localhost:37018,localhost:37019" }
      end

      let(:error) do
        Moped::Errors::PotentialReconfiguration.new({}, details)
      end

      it "returns true" do
        error.should be_connection_failure
      end
    end
  end
end
