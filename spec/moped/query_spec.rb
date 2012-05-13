require "spec_helper"

describe Moped::Query do

  shared_examples_for "Query" do

    let!(:scope) do
      object_id
    end

    before do
      users.find.remove_all
    end

    let(:documents) do
      [
        { "_id" => Moped::BSON::ObjectId.new, "scope" => scope },
        { "_id" => Moped::BSON::ObjectId.new, "scope" => scope }
      ]
    end

    it "raises a query failure exception for invalid queries" do
      expect {
        users.find("age" => { "$in" => nil }).first
      }.to raise_exception(Moped::Errors::QueryFailure)
    end

    describe "#limit" do

      before do
        users.insert(documents)
      end

      it "limits the query" do
        users.find(scope: scope).limit(1).to_a.size.should eq(1)
      end
    end

    describe "#skip" do

      before do
        users.insert(documents)
      end

      it "skips +n+ documents" do
        users.find(scope: scope).skip(1).to_a.size.should eq(1)
      end
    end

    describe "#sort" do

      let(:documents) do
        [
          { "_id" => Moped::BSON::ObjectId.new, "scope" => scope, "n" => 0 },
          { "_id" => Moped::BSON::ObjectId.new, "scope" => scope, "n" => 1 }
        ]
      end

      before do
        users.insert(documents)
      end

      it "sorts the results" do
        users.find(scope: scope).sort(n: -1).to_a.should eq documents.reverse
      end
    end

    describe "#distinct" do

      let(:documents) do
        [
          { count: 0, scope: scope },
          { count: 1, scope: scope },
          { count: 1, scope: scope }
        ]
      end

      before do
        users.insert(documents)
      end

      it "returns distinct values for +key+" do
        users.find(scope: scope).distinct(:count).should =~ [0, 1]
      end
    end

    describe "#select" do

      let(:documents) do
        [
          { "scope" => scope, "n" => 0 },
          { "scope" => scope, "n" => 1 }
        ]
      end

      before do
        users.insert(documents)
      end

      let(:results) do
        users.find(scope: scope).select(_id: 0).to_a
      end

      it "changes the fields returned" do
        results.should include(documents.first)
        results.should include(documents.last)
      end
    end

    describe "#one" do

      before do
        users.insert(documents)
      end

      it "respects #sort" do
        users.find(scope: scope).sort(_id: -1).one.should eq documents.last
      end
    end

    describe "#explain" do

      context "when a sort exists" do

        let(:stats) do
          Support::Stats.collect do
            users.find(scope: scope).sort(_id: 1).explain
          end
        end

        let(:operation) do
          stats[node_for_reads].grep(Moped::Protocol::Query).last
        end

        it "updates to a mongo advanced selector" do
          operation.selector.should eq(
            "$query" => { scope: scope },
            "$explain" => true,
            "$orderby" => { _id: 1 }
          )
        end
      end

      context "when no sort exists" do

        let(:stats) do
          Support::Stats.collect do
            users.find(scope: scope).explain
          end
        end

        let(:operation) do
          stats[node_for_reads].grep(Moped::Protocol::Query).last
        end

        it "updates to a mongo advanced selector" do
          operation.selector.should eq(
            "$query" => { scope: scope },
            "$explain" => true,
            "$orderby" => {}
          )
        end
      end
    end

    describe "#each" do

      context "when no options are provided" do

        before do
          users.insert(documents)
        end

        it "yields each document" do
          users.find(scope: scope).each.with_index do |document, index|
            documents.should include(document)
          end
        end
      end

      context "when a limit is provided" do

        before do
          users.insert(100.times.map { Hash["scope" => scope] })
        end

        let(:stats) do
          Support::Stats.collect do
            users.find(scope: scope).limit(5).entries
          end
        end

        it "closes open cursors" do
          stats[node_for_reads].grep(Moped::Protocol::KillCursors).count.should eq 1
        end
      end

      context "when no limit is provided" do

        before do
          users.insert(102.times.map { Hash["scope" => scope] })
        end

        let(:stats) do
          Support::Stats.collect do
            users.find(scope: scope).entries
          end
        end

        it "fetches more" do
          stats[node_for_reads].grep(Moped::Protocol::GetMore).count.should eq 1
        end
      end
    end

    describe "#count" do

      let(:documents) do
        [
          { "_id" => Moped::BSON::ObjectId.new, "scope" => scope },
          { "_id" => Moped::BSON::ObjectId.new, "scope" => scope },
          { "_id" => Moped::BSON::ObjectId.new }
        ]
      end

      before do
        users.insert(documents)
      end

      it "returns the number of matching document" do
        users.find(scope: scope).count.should eq 2
      end

      it 'return the number of document with limit' do
        users.find(scope: scope).limit(1).count.should eq 1
      end

      it 'return the number of document with limit and offset' do
        users.find(scope: scope).limit(1).skip(4).count.should eq 0
      end
    end

    describe "#update" do

      before do
        users.insert(documents)
        users.find(scope: scope).update("$set" => { "updated" => true })
      end

      it "updates the first matching document" do
        users.find(scope: scope, updated: true).count.should eq 1
      end
    end

    describe "#update_all" do

      before do
        users.insert(documents)
        users.find(scope: scope).update_all("$set" => { "updated" => true })
      end

      it "updates all matching documents" do
        users.find(scope: scope, updated: true).count.should eq 2
      end
    end

    describe "#upsert" do

      context "when a document exists" do

        before do
          users.insert(scope: scope, counter: 1)
          users.find(scope: scope).upsert("$inc" => { counter: 1 })
        end

        it "updates the document" do
          users.find(scope: scope).one["counter"].should eq 2
        end
      end

      context "when no document exists" do

        before do
          users.find(scope: scope).upsert("$inc" => { counter: 1 })
        end

        it "inserts a document" do
          users.find(scope: scope).one["counter"].should eq 1
        end
      end
    end

    describe "#remove" do

      before do
        users.insert(documents)
        users.find(scope: scope).remove
      end

      it "removes the first matching document" do
        users.find(scope: scope).count.should eq 1
      end
    end

    describe "#remove_all" do

      before do
        users.insert(documents)
        users.find(scope: scope).remove_all
      end

      it "removes all matching documents" do
        users.find(scope: scope).count.should eq 0
      end
    end
  end

  context "with a local connection" do

    let(:session) do
      Moped::Session.new([ "127.0.0.1:27017" ], database: "moped_test")
    end

    let(:users) do
      session[:users]
    end

    let(:node_for_reads) do
      :primary
    end

    include_examples "Query"

    describe "#each" do

      context "with a limit and large result set" do

        before do
          11.times do
            users.insert(scope: scope, large_field: "a"*1_000_000)
          end
        end

        let(:stats) do
          Support::Stats.collect do
            users.find(scope: scope).limit(10).entries
          end
        end

        it "executes a get more" do
          stats[:primary].grep(Moped::Protocol::GetMore).count.should eq 1
        end

        it "closes the cursors" do
          stats[:primary].grep(Moped::Protocol::KillCursors).count.should eq 1
        end
      end
    end
  end

  context "with a remote connection", mongohq: :auth do

    before(:all) do
      @session = Support::MongoHQ.auth_session
    end

    let(:users) do
      @session[:users]
    end

    let(:node_for_reads) do
      :primary
    end

    include_examples "Query"
  end

  context "with a remote replica set connection with eventual consistency", mongohq: :replica_set do

    before(:all) do
      @session = Support::MongoHQ.replica_set_session.with(safe: true, consistency: :eventual)
      @session.command ping: 1
    end

    let(:users) do
      @session[:users]
    end

    let(:node_for_reads) do
      :secondary
    end

    include_examples "Query"
  end

  context "with a remote replica set connection with strong consistency", mongohq: :replica_set do

    before(:all) do
      @session = Support::MongoHQ.replica_set_session.with(safe: true, consistency: :strong)
    end

    let(:users) do
      @session[:users]
    end

    let(:node_for_reads) do
      :primary
    end

    include_examples "Query"
  end

  context "with a local replica set w/ failover", replica_set: true do

    let(:session) do
      Moped::Session.new seeds, database: "moped_test"
    end

    let(:scope) do
      object_id
    end

    before do
      # Force connection before recording stats
      session.command ping: 1
    end

    context "when running with eventual consistency" do

      let(:stats) do
        Support::Stats.collect do
          session.with(consistency: :eventual)[:users].find(scope: scope).entries
        end
      end

      it "queries a secondary node" do
        stats[:secondary].grep(Moped::Protocol::Query).count.should eq 1
        stats[:primary].should be_empty
      end

      it "sets the slave ok flag" do
        query = stats[:secondary].grep(Moped::Protocol::Query).first
        query.flags.should include :slave_ok
      end

      context "and no secondaries are available" do

        before do
          @secondaries.each(&:stop)
        end

        it "queries the primary node" do
          stats[:primary].grep(Moped::Protocol::Query).count.should eq 1
        end
      end
    end

    context "when running with strong consistency" do

      let(:stats) do
        Support::Stats.collect do
          session.with(consistency: :strong)[:users].find(scope: scope).entries
        end
      end

      it "queries the primary node" do
        stats[:primary].grep(Moped::Protocol::Query).count.should eq 1
        stats[:secondary].should be_empty
      end

      it "does not set the slave ok flag" do
        query = stats[:primary].grep(Moped::Protocol::Query).first
        query.flags.should_not include :slave_ok
      end
    end
  end
end
