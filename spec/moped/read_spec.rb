require "spec_helper"

describe Moped::Read do

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
            node.instance_variable_set(:@auth, { database => [ user, pass ]})
            replica_set_node.unauthorized_on_next_message!
          end

          it "retries the operation" do
            expect(read.execute(node)).to_not be_nil
          end
        end

        context "when no credentials exist on the node" do

          before do
            node.instance_variable_set(:@auth, {})
            replica_set_node.unauthorized_on_next_message!
          end

          it "raises a failure error" do
            expect {
              read.execute(node)
            }.to raise_error(Moped::Read::Failure)
          end
        end
      end

      context "when the failure is not due to authentication" do

        before do
          replica_set_node.query_failure_on_next_message!
        end

        it "returns the reply" do
          expect {
            read.execute(node)
          }.to raise_error(Moped::Read::Failure)
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

    context "when the operation is a query" do

      let(:operation) do
        Moped::Protocol::Query.new(database, collection, {}, {})
      end

      it_behaves_like "a read operation with failover"
    end

    context "when the operation is a command" do

      let(:operation) do
        Moped::Protocol::Command.new(database, { ismaster: 1 }, {})
      end

      it_behaves_like "a read operation with failover"
    end
  end
end
