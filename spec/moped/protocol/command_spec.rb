require "spec_helper"

describe Moped::Protocol::Command do

  describe "#initialize" do
    let(:command) do
      described_class.new(:moped, ismaster: 1)
    end

    it "sets the query's full collection name" do
      command.full_collection_name.should eq "moped.$cmd"
    end

    it "sets the query's selector to the command provided" do
      command.selector.should eq(ismaster: 1)
    end

    it "sets the query's limit to -1" do
      command.limit.should eq(-1)
    end
  end

end
