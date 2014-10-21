require "spec_helper"

describe Moped::Cursor do

  describe "#request_limit" do

    let(:session) do
      Moped::Session.new([ "localhost:27017" ], database: "moped_test")
    end

    context "when the query has a limit" do

      let(:query) do
        session[:users].find.limit(10)
      end

      let(:cursor) do
        described_class.new(session, query.operation)
      end

      it "returns the query limit" do
        cursor.request_limit.should eq(10)
      end
    end

    context "when the query has no limit" do

      let(:query) do
        session[:users].find
      end

      let(:cursor) do
        described_class.new(session, query.operation)
      end

      it "returns 0" do
        cursor.request_limit.should eq(0)
      end
    end

    context "when the query has a batch size" do

      let(:query) do
        session[:users].find.batch_size(10)
      end

      let(:cursor) do
        described_class.new(session, query.operation)
      end

      it "returns the batch size" do
        cursor.request_limit.should eq(10)
      end
    end

    context "when the query has a batch size of 1" do
      let(:query) do
        users.find.batch_size(1)
      end

      let(:users) do
        session[:users]
      end

      before do
        users.find.remove_all
        users.insert([ { "name" => "one" } , { "name" => "two" } , { "name" => "three" } ])
      end

      it "iterates over each user" do
        docs = []

        query.each do |doc|
          docs << doc
        end

        docs.count.should eq(3)
      end
    end

    context "when the query has a limit and batch size" do

      let(:query) do
        session[:users].find.limit(1000).batch_size(100)
      end

      let(:cursor) do
        described_class.new(session, query.operation)
      end

      it "returns the smaller value" do
        cursor.request_limit.should eq(100)
      end
    end
  end
end
