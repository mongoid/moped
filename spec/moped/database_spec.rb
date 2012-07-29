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
end
