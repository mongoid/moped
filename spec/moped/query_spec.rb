require "spec_helper"

describe Moped::Query do

  [ :clone, :dup ].each do |method|

    describe "##{method}" do

      let(:session) do
        Moped::Session.new([ "127.0.0.1:27017" ], database: "moped_test")
      end

      let(:users) do
        session[:users]
      end

      let(:query) do
        users.find.select(_id: 1)
      end

      let!(:copied) do
        query.send(method)
      end

      it "dups the operation" do
        copied.operation.should_not equal(query.operation)
      end

      it "dups the selector" do
        copied.selector.should_not equal(query.selector)
      end
    end
  end

  describe "#tailable" do

    let(:session) do
      Moped::Session.new([ "127.0.0.1:27017" ], database: "moped_test")
    end

    let(:events) do
      session[:capped_events]
    end

    before do
      begin
        session.command(
          create: "capped_events",
          capped: true,
          size: 10000000,
          max: 10
        )
      rescue Moped::Errors::OperationFailure
      end
    end

    context "when the collection is capped" do

      before do
        events.insert({ "name" => "create" })
      end

      after do
        events.drop
      end

      let(:query) do
        events.find.tailable
      end

      let(:cursor) do
        query.cursor
      end

      it "sets the tailable flag" do
        query.operation.flags.should include :tailable
      end

      it "sets the await data flag" do
        query.operation.flags.should include :await_data
      end

      it "returns the documents from the tail" do
        cursor.take(1).first["name"].should eq("create")
      end

      context "when inserting another document" do

        before do
          events.insert({ "name" => "delete" })
        end

        it "keeps the cursor open" do
          mutex = Mutex.new
          proceed = ConditionVariable.new

          Thread.new do
            mutex.synchronize { proceed.wait(mutex) }
            events.insert({ "name" => "new" })
          end
          arr = %w(create delete new)

          cursor.each_with_index do |entry, i|
            expect(entry['name']).to eq(arr.shift)

            case entry['name']
            when 'new'
              break
            when 'delete'
              mutex.synchronize { proceed.signal }
            end
          end

          expect(arr.length).to eq(0)
        end
      end
    end
  end

  shared_examples_for "Modify" do

    before do
      users.find.remove_all
    end

    let(:one) do
      BSON::ObjectId.new
    end

    let(:two) do
      BSON::ObjectId.new
    end

    let(:doc_one) do
      { "_id" => one, "name" => "Placebo" }
    end

    let(:doc_two) do
      { "_id" => two, "name" => "Underworld" }
    end

    describe "#modify" do

      before do
        users.insert([ doc_one, doc_two ])
      end

      context "when the selector matches" do

        context "when providing no options" do

          let!(:result) do
            users.find(_id: one).modify({ "$set" => { name: "Tool" }})
          end

          it "returns the first matching document" do
            result.should eq(doc_one)
          end

          it "updates the document in the database" do
            users.find(_id: one).first["name"].should eq("Tool")
          end
        end

        context "when providing options" do

          context "when providing new: true" do

            let!(:result) do
              users.find(_id: one).modify({ "$set" => { name: "Tool" }}, new: true)
            end

            it "returns the updated document" do
              result["name"].should eq("Tool")
            end

            it "updates the document in the database" do
              users.find(_id: one).first["name"].should eq("Tool")
            end
          end

          context "when providing new: false" do

            let!(:result) do
              users.find(_id: one).modify({ "$set" => { name: "Tool" }}, new: false)
            end

            it "returns the first matching document" do
              result.should eq(doc_one)
            end

            it "updates the document in the database" do
              users.find(_id: one).first["name"].should eq("Tool")
            end
          end

          context "when providing remove: true" do

            let!(:result) do
              users.find(_id: one).modify({ "$set" => { name: "Tool" }}, remove: true)
            end

            it "returns the first matching document" do
              result.should eq(doc_one)
            end

            it "removes the document from the database" do
              users.find(_id: one).first.should be_nil
            end
          end

          context "when providing remove: false" do

            let!(:result) do
              users.find(_id: one).modify({ "$set" => { name: "Tool" }}, remove: false)
            end

            it "returns the first matching document" do
              result.should eq(doc_one)
            end

            it "removes the document from the database" do
              users.find(_id: one).first["name"].should eq("Tool")
            end
          end

          context "when providing upsert: true" do

            context "when not providing new: true" do

              let!(:result) do
                users.find(likes: 1).modify({ "$set" => { name: "Tool" }}, upsert: true)
              end

              it "returns a hash" do
                result.should be_a(Hash)
              end

              it "returns an empty result" do
                result.should be_empty
              end

              it "inserts the document in the database" do
                users.find(likes: 1).first["name"].should eq("Tool")
              end
            end

            context "when providing new: true" do

              let!(:result) do
                users.find(likes: 1).
                  modify({ "$set" => { name: "Tool" }}, upsert: true, new: true)
              end

              it "returns the new document" do
                result["name"].should eq("Tool")
              end

              it "inserts the document in the database" do
                users.find(likes: 1).first["name"].should eq("Tool")
              end
            end
          end

          context "when providing upsert: false" do

            let!(:result) do
              users.find(likes: 1).modify({ "$set" => { name: "Tool" }}, remove: false)
            end

            it "returns the nil" do
              result.should be_nil
            end

            it "does not insert into the database" do
              users.find(likes: 1).first.should be_nil
            end
          end
        end
      end

      context "when the selector does not match anything" do

        let(:result) do
          users.
            find(_id: BSON::ObjectId.new).
            modify("$set" => { name: "Underworld" })
        end

        it "returns nil" do
          result.should be_nil
        end
      end
    end
  end

  shared_examples_for "Query" do

    let!(:scope) do
      object_id
    end

    before do
      users.find.remove_all
    end

    let(:documents) do
      [
        { "_id" => BSON::ObjectId.new, "scope" => scope },
        { "_id" => BSON::ObjectId.new, "scope" => scope }
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
          { "_id" => BSON::ObjectId.new, "scope" => scope, "n" => 0 },
          { "_id" => BSON::ObjectId.new, "scope" => scope, "n" => 1 }
        ]
      end

      before do
        users.insert(documents)
      end

      it "sorts the results" do
        users.find(scope: scope).sort(n: -1).to_a.should eq documents.reverse
      end
    end

    describe "#hint" do

      let(:documents) do
        [
          { "_id" => BSON::ObjectId.new, "scope" => scope, "n" => 0 },
          { "_id" => BSON::ObjectId.new, "scope" => scope, "n" => 1 }
        ]
      end

      before do
        users.insert(documents)
      end

      it "works transparently when specifying an existing index" do
        users.find(scope: scope).hint(_id: 1).to_a.should eq documents
      end

      it "raises an error when hinting an invalid index" do
        expect {
          users.find(scope: scope).hint(scope: 1).to_a
        }.to raise_error(Moped::Errors::QueryFailure)
      end
    end

    describe "#max_scan" do

      let(:document1) do
        { "_id" => BSON::ObjectId.new, "scope" => scope, "n" => 0 }
      end

      let(:document2) do
        { "_id" => BSON::ObjectId.new, "scope" => scope, "n" => 1 }
      end

      let(:documents) do
        [ document1, document2 ]
      end

      before do
        users.insert(documents)
      end

      it "limits the number of documents returned" do
        users.find(scope: scope).max_scan(1).to_a.size.should eq(1)
      end
    end

    describe "#min" do
      let(:document1) do
        { "_id" => BSON::ObjectId.new, "scope" => scope, "n" => 0 }
      end

      let(:document2) do
        { "_id" => BSON::ObjectId.new, "scope" => scope, "n" => 1 }
      end

      let(:documents) do
        [ document1, document2 ]
      end

      before do
        users.insert(documents)
      end

      it "filter out documents lt than the indexed value" do
        users.find(scope: scope).min(_id: document2['_id']).to_a.should eq [ document2 ]
      end
    end

    describe "#max" do
      let(:document1) do
        { "_id" => BSON::ObjectId.new, "scope" => scope, "n" => 0 }
      end

      let(:document2) do
        { "_id" => BSON::ObjectId.new, "scope" => scope, "n" => 1 }
      end

      let(:documents) do
        [ document1, document2 ]
      end

      before do
        users.insert(documents)
      end

      it "filter out documents gte than the indexed value" do
        users.find(scope: scope).max(_id: document2['_id']).to_a.should eq [ document1 ]
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

        before do
          2.times do |n|
            users.insert({ likes: n })
          end
        end

        let(:explain) do
          users.find(likes: { "$exists" => false }).sort(_id: 1).explain
        end

        let(:stats) do
          Support::Stats.collect { explain }
        end

        let(:operation) do
          stats[node_for_reads].grep(Moped::Protocol::Query).last
        end

        it "updates to a mongo advanced selector" do
          operation.selector.should eq(
            "$query" => { likes: { "$exists" => false }},
            "$explain" => true,
            "$orderby" => { _id: 1 }
          )
        end

        it "scans more than one document" do
          explain["nscanned"].should eq(2)
        end

        it "scans more than one object" do
          explain["nscannedObjects"].should eq(2)
        end
      end

      context "when no sort exists" do

        before do
          2.times do |n|
            users.insert({ likes: n })
          end
        end

        let(:explain) do
          users.find(created_at: { "$exists" => false }).explain
        end

        let(:stats) do
          Support::Stats.collect { explain }
        end

        let(:operation) do
          stats[node_for_reads].grep(Moped::Protocol::Query).last
        end

        it "updates to a mongo advanced selector" do
          operation.selector.should eq(
            "$query" => { created_at: { "$exists" => false }},
            "$explain" => true
          )
        end

        it "scans more than one document" do
          explain["nscanned"].should eq(2)
        end

        it "scans more than one object" do
          explain["nscannedObjects"].should eq(2)
        end
      end

      context "when a hint exists" do

        before do
          2.times do |n|
            users.insert({ likes: n })
          end
        end

        let(:explain) do
          users.find(likes: { "$exists" => false }).hint(_id: 1).explain
        end

        let(:stats) do
          Support::Stats.collect { explain }
        end

        let(:operation) do
          stats[node_for_reads].grep(Moped::Protocol::Query).last
        end

        it "updates to a mongo advanced selector" do
          operation.selector.should eq(
            "$query" => { likes: { "$exists" => false }},
            "$explain" => true,
            "$hint" => { _id: 1 }
          )
        end

        it "scans more than one document" do
          explain["nscanned"].should eq(2)
        end

        it "scans more than one object" do
          explain["nscannedObjects"].should eq(2)
        end
      end

      context "when a max scan exists" do

        before do
          2.times do |n|
            users.insert({ likes: n })
          end
        end

        let(:explain) do
          users.find(likes: { "$exists" => false }).max_scan(1).explain
        end

        let(:stats) do
          Support::Stats.collect { explain }
        end

        let(:operation) do
          stats[node_for_reads].grep(Moped::Protocol::Query).last
        end

        it "updates to a mongo advanced selector" do
          operation.selector.should eq(
            "$query" => { likes: { "$exists" => false }},
            "$explain" => true, "$maxScan" => 1
          )
        end

        it "scans up to the number of objects in the max scan" do
          explain["nscannedObjects"].should eq(1)
        end

        context "and a sort exists" do

          let(:explain) do
            users.find(likes: { "$exists" => false }).max_scan(10).sort(_id: 1).explain
          end

          let(:stats) do
            Support::Stats.collect { explain }
          end

          let(:operation) do
            stats[node_for_reads].grep(Moped::Protocol::Query).last
          end

          it "updates to a mongo advanced selector" do
            operation.selector.should eq(
              "$query" => { likes: { "$exists" => false }}, "$explain" => true,
              "$orderby" => { _id: 1 }, "$maxScan" => 10
            )
          end
        end
      end

      context "when a limit exists" do

        before do
          4.times do |n|
            users.insert({ likes: n })
          end
        end

        let(:explain) do
          users.find(likes: { "$gt" => 1 }).limit(2).explain
        end

        let(:stats) do
          Support::Stats.collect { explain }
        end

        let(:operation) do
          stats[node_for_reads].grep(Moped::Protocol::Query).last
        end

        it "updates to a mongo advanced selector" do
          operation.selector.should eq(
            "$query" => { likes: { "$gt" => 1 }},
            "$explain" => true
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
          users.find(scope: scope).cursor.each_with_index do |document, index|
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
          { "_id" => BSON::ObjectId.new, "scope" => scope },
          { "_id" => BSON::ObjectId.new, "scope" => scope },
          { "_id" => BSON::ObjectId.new }
        ]
      end

      before do
        users.insert(documents)
      end

      context "when no limiting is provided" do

        context "when passing no arguments" do

          it "returns the number of matching document" do
            users.find(scope: scope).count.should eq(2)
          end

          it "returns a fixnum" do
            users.find(scope: scope).count.should be_a(Integer)
          end
        end

        context "when passing true" do

          it "returns the number of matching document" do
            users.find(scope: scope).count(true).should eq(2)
          end
        end
      end

      context "when limiting options are provided" do

        context "when passing no arguments" do

          it "returns the number of matching document" do
            users.find(scope: scope).limit(1).count.should eq(2)
          end
        end

        context "when passing true" do

          it "returns the count with limiting applied" do
            users.find(scope: scope).limit(1).count(true).should eq(1)
          end
        end
      end
    end

    describe "#update" do

      context "when no sorting is provided" do

        before do
          users.insert(documents)
          users.find(scope: scope).update("$set" => { "updated" => true })
        end

        it "updates the first matching document" do
          users.find(scope: scope, updated: true).count.should eq 1
        end
      end

      context "when sorting is provided" do

        before do
          users.insert(documents)
          users.find(scope: scope).
            sort(updated: 1).
            update("$set" => { "updated" => true })
        end

        it "updates the first matching document" do
          users.find(scope: scope, updated: true).count.should eq 1
        end
      end
    end

    describe "#update_all" do

      context "when providing a $ne query" do

        before do
          users.insert(documents)
          users.find(scope: { "$ne" => nil }).update_all("$set" => { "scope" => nil })
        end

        it "updates all matching documents" do
          users.find(scope: { "$ne" => nil }).count.should eq(0)
        end
      end

      context "when no sorting is provided" do

        before do
          users.insert(documents)
          users.find(scope: scope).update_all("$set" => { "updated" => true })
        end

        it "updates all matching documents" do
          users.find(scope: scope, updated: true).count.should eq 2
        end
      end

      context "when sorting is provided" do

        before do
          users.insert(documents)
          users.find(scope: scope).
            sort(updated: 1).
            update_all("$set" => { "updated" => true })
        end

        it "updates all matching documents" do
          users.find(scope: scope, updated: true).count.should eq 2
        end
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
      end

      context "when ordering exists on the query" do

        before do
          users.find(scope: scope).sort(scope: 1).remove
        end

        it "removes the first matching document" do
          users.find(scope: scope).count.should eq(1)
        end
      end

      context "when no ordering exists on the query" do

        before do
          users.find(scope: scope).remove
        end

        it "removes the first matching document" do
          users.find(scope: scope).count.should eq(1)
        end
      end
    end

    describe "#remove_all" do

      before do
        users.insert(documents)
      end

      context "when ordering exists on the query" do

        before do
          users.find(scope: scope).sort(scope: 1).remove_all
        end

        it "removes all matching documents" do
          users.find(scope: scope).count.should eq(0)
        end
      end

      context "when no ordering exists on the query" do

        before do
          users.find(scope: scope).remove_all
        end

        it "removes all matching documents" do
          users.find(scope: scope).count.should eq(0)
        end
      end
    end
  end

  context "with a local connection" do

    let(:session) do
      Moped::Session.new([ "127.0.0.1:27017" ], database: "moped_test", write: { w: 0 })
    end

    let(:users) do
      session[:users]
    end

    let(:node_for_reads) do
      :primary
    end

    include_examples "Modify"
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

      context "without a limit and large result set" do
        before do
          11.times do
            users.insert(scope: scope, large_field: "a"*1_000_000)
          end
        end

        it "raises an error when the cursor cannot be found" do
          expect {
            Support::Stats.collect do
              users.find(scope: scope).each do
                stats = Support::Stats.instance_variable_get(:@stats)[:primary]
                cursor_id = stats[-1].instance_variable_get(:@cursor_id)
                session.cluster.nodes.first.kill_cursors([cursor_id]) if cursor_id
              end
            end
          }.to raise_error(Moped::Errors::CursorNotFound)
        end
      end
    end
  end

  context "with test commands enabled" do

    let(:session) do
      Moped::Session.new([ "127.0.0.1:#{port}" ], database: "moped_test")
    end

    let(:users) do
      session.with(safe: true)[:users]
    end

    describe "when a query take too long" do
      let(:port) { 31104 }

      before do
        start_mongo_server(port, "--setParameter enableTestCommands=1")
        Process.detach(spawn("echo 'db.adminCommand({sleep: 1, w: true, secs: 10})' | mongo localhost:#{port} 2>&1 > /dev/null"))
        sleep 1 # to sleep command on mongodb begins work
      end

      after do
        stop_mongo_server(port)
      end

      it "raises a operation timeout exception" do
        time = Benchmark.realtime do
          expect {
            Timeout::timeout(7) do
              users.find("age" => { "$gte" => 65 }).first
            end
          }.to raise_exception("Took more than 5 seconds to receive data.")
        end
        expect(time).to be < 5.5
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

  context "with a remote replica set connection with secondary preferred",
    mongohq: :replica_set do

    before(:all) do
      @session = Support::MongoHQ.replica_set_session.with(read: :secondary_preferred)
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

  context "with a remote replica set connection with secondary preferred and ssl",
    mongohq: :replica_set_ssl do

    before(:all) do
      @session = Support::MongoHQ.ssl_replica_set_session.with(read: :secondary_preferred)
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

  context "with a remote replica set connection with read primary",
    mongohq: :replica_set do

    before(:all) do
      @session = Support::MongoHQ.replica_set_session.with(read: :primary)
    end

    let(:users) do
      @session[:users]
    end

    let(:node_for_reads) do
      :primary
    end

    include_examples "Modify"
    include_examples "Query"
  end

  context "with a remote replica set connection with read primary and ssl",
    mongohq: :replica_set_ssl do

    before(:all) do
      @session = Support::MongoHQ.ssl_replica_set_session.with(read: :primary)
    end

    let(:users) do
      @session[:users]
    end

    let(:node_for_reads) do
      :primary
    end

    include_examples "Modify"
    include_examples "Query"
  end

  context "with a local replica set w/ failover", replica_set: true do

    let(:session) do
      Moped::Session.new(seeds, database: "moped_test")
    end

    let(:scope) do
      object_id
    end

    before do
      # Force connection before recording stats
      session.command ping: 1
    end

    context "when running with secondary preferred" do

      let(:stats) do
        Support::Stats.collect do
          session.with(read: :secondary_preferred)[:users].find(scope: scope).entries
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

    context "when running with read primary" do

      let(:stats) do
        Support::Stats.collect do
          session.with(read: :primary)[:users].find(scope: scope).entries
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
