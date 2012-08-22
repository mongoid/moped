require "spec_helper"

describe Moped::Database do

  let(:session) do
    Moped::Session.new %w[127.0.0.1:27017], database: "moped_test"
  end

  describe "#initialize" do

    context "when the name contains spaces" do

      it "raises an error" do
        expect {
          described_class.new(session, "test name")
        }.to raise_error(Moped::Errors::InvalidDatabaseName)
      end
    end

    context "when the name contains dots" do

      it "raises an error" do
        expect {
          described_class.new(session, "test.name")
        }.to raise_error(Moped::Errors::InvalidDatabaseName)
      end
    end

    context "when the name contains $" do

      it "raises an error" do
        expect {
          described_class.new(session, "test$name")
        }.to raise_error(Moped::Errors::InvalidDatabaseName)
      end
    end

    context "when the name contains /" do

      it "raises an error" do
        expect {
          described_class.new(session, "test/name")
        }.to raise_error(Moped::Errors::InvalidDatabaseName)
      end
    end

    context "when the name contains \\" do

      it "raises an error" do
        expect {
          described_class.new(session, "test\\name")
        }.to raise_error(Moped::Errors::InvalidDatabaseName)
      end
    end

    context "when the name contains \0" do

      it "raises an error" do
        expect {
          described_class.new(session, "test\0name")
        }.to raise_error(Moped::Errors::InvalidDatabaseName)
      end
    end
  end


  describe "#collection_names" do

    let(:collection_names) do
      session.collection_names
    end

    before :each do
      session.drop
      names.map do |name|
        session.command create: name
      end
    end

    context "when name doesn't include system" do

      let(:names) do
        %w[ users comments ]
      end

      it "returns the name of all non system collections" do
        collection_names.sort.should eq %w[ users comments ].sort
      end
    end

    context "when name includes system not at the beginning" do

      let(:names) do
        %w[ users comments_system_fu ]
      end

      it "returns the name of all non system collections" do
        collection_names.sort.should eq %w[ users comments_system_fu ].sort
      end
    end

    context "when name includes system at the beginning" do

      let(:names) do
        %w[ users system_comments_fu ]
      end

      it "returns the name of all non system collections" do
        collection_names.sort.should eq %w[ users ].sort
      end
    end
  end
end
