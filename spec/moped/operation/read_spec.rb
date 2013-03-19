require "spec_helper"

describe Moped::Operation::Read do

  shared_examples_for "a read operation with failover" do

    let(:user) do
      "test_user"
    end

    let(:pass) do
      "password"
    end

    let(:read) do
      described_class.new(operation)
    end

    context "when the read fails" do

      context "when the failure is due to authentication" do

        context "when credentials exist on the node" do

          before do
            node.instance_variable_set(:@credentials, { database => [ user, pass ]})
            replica_set_node.unauthorized_on_next_message!
          end

          it "retries the operation" do
            expect(read.execute(node)).to_not be_nil
          end
        end

        context "when no credentials exist on the node" do

          before do
            node.instance_variable_set(:@credentials, {})
            replica_set_node.unauthorized_on_next_message!
          end

          it "raises a failure error" do
            expect {
              read.execute(node)
            }.to raise_error(exception)
          end
        end
      end

      context "when the failure is not due to authentication" do

        before do
          replica_set_node.query_failure_on_next_message!
        end

        it "raises a failure error" do
          expect {
            read.execute(node)
          }.to raise_error(exception)
        end
      end
    end

    context "when the read does not fail" do

      it "returns the reply" do
        expect(read.execute(node)).to_not be_nil
      end
    end
  end

  describe "#initialize" do

    let(:database) do
      "moped_test"
    end

    let(:collection) do
      "users"
    end

    let(:query) do
      Moped::Protocol::Query.new(database, collection, {}, {})
    end

    let(:read) do
      described_class.new(query)
    end

    it "sets the database" do
      expect(read.database).to eq(database)
    end

    it "sets the operation" do
      expect(read.operation).to eq(query)
    end
  end

  describe "#execute", replica_set: true do

    let(:replica_set_node) do
      @replica_set.nodes.first
    end

    let(:node) do
      Moped::Node.new(replica_set_node.address)
    end

    let(:database) do
      "moped_test"
    end

    let(:collection) do
      "users"
    end

    let(:session) do
      Moped::Session.new([ "127.0.0.1:27017" ], database: database)
    end

    context "when the operation is a query" do

      let(:operation) do
        Moped::Protocol::Query.new(database, collection, {}, {})
      end

      let(:exception) do
        Moped::Errors::QueryFailure
      end

      it_behaves_like "a read operation with failover"
    end

    context "when the operation is a command" do

      let(:operation) do
        Moped::Protocol::Command.new(database, { ismaster: 1 }, {})
      end

      let(:exception) do
        Moped::Errors::OperationFailure
      end

      it_behaves_like "a read operation with failover"
    end

    context "when the operation is a get more" do

      let(:query) do
        Moped::Protocol::Query.new(database, collection, {}, {})
      end

      before do
        200.times do |n|
          session[collection].insert({ a: n })
        end
      end

      after do
        session[collection].find.remove_all
      end

      let(:cursor_id) do
        described_class.new(query).execute(node).cursor_id
      end

      let(:operation) do
        Moped::Protocol::GetMore.new(database, collection, cursor_id, 10)
      end

      let(:exception) do
        Moped::Errors::QueryFailure
      end

      it_behaves_like "a read operation with failover"

      context "when the cursor is not found" do

        let(:not_found) do
          Moped::Protocol::GetMore.new(database, collection, 123131231311, 10)
        end

        it "raises a cursor not found error" do
          expect {
            described_class.new(not_found).execute(node)
          }.to raise_error(Moped::Errors::CursorNotFound)
        end
      end
    end
  end
end
