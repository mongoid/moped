require "spec_helper"

describe Moped::Indexes do
  let(:session) do
    Moped::Session.new %w[127.0.0.1:27017], database: "moped_test"
  end

  let(:indexes) do
    session[:users].indexes
  end

  before do
    begin
      indexes.drop
    rescue Exception
    end
  end

  describe "#create" do
    context "when called without extra options" do
      it "creates an index with no options" do
        indexes.create name: 1
        indexes[name: 1].should_not be_nil
      end
    end

    context "when called with extra options" do
      it "creates an index with the extra options" do
        indexes.create({name: 1}, {unique: true, dropDups: true})
        index = indexes[name: 1]
        index["unique"].should be_true
        index["dropDups"].should be_true
      end
    end
  end

  describe "#drop" do
    context "when provided a key" do
      it "drops the index" do
        indexes.create name: 1
        indexes.drop(name: 1).should be_true
      end
    end

    context "when not provided a key" do
      it "drops all indexes" do
        indexes.create name: 1
        indexes.create age: 1
        indexes.drop
        indexes[name: 1].should be_nil
        indexes[age: 1].should be_nil
      end
    end
  end

end
