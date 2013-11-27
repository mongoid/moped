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

    context "when the cursor is iterated upon out-of-block" do

      before do
        session[:users].insert({ "name" => "create" })
      end

      let(:query) do
        session[:users].find.limit(1)
      end

      let(:cursor) do
        described_class.new(session, query.operation)
      end

      it "advances the cursor_id" do
        cursor.take(1)
        cursor.take(1).should be_empty
      end
    end
  end
end
