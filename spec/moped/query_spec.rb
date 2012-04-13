require "spec_helper"

describe Moped::Query do

  let(:session) do
    mock(Moped::Session)
  end

  let(:database) do
    mock(
      Moped::Database,
      name: "moped",
      session: session
    )
  end

  let(:collection) do
    mock(
      Moped::Collection,
      database: database,
      name: "users"
    )
  end

  let(:selector) do
    Hash[ a: 1 ]
  end

  let(:query) do
    described_class.new collection, selector
  end

  describe "#initialize" do

    it "stores the collection" do
      query.collection.should eq collection
    end

    it "stores the selector" do
      query.selector.should eq selector
    end
  end

  describe "#limit" do

    it "sets the query operation's limit field" do
      query.limit(5)
      query.operation.limit.should eq 5
    end

    it "returns the query" do
      query.limit(5).should eql query
    end
  end

  describe "#skip" do

    it "sets the query operation's skip field" do
      query.skip(5)
      query.operation.skip.should eq 5
    end

    it "returns the query" do
      query.skip(5).should eql query
    end
  end

  describe "#select" do

    it "sets the query operation's fields" do
      query.select(a: 1)
      query.operation.fields.should eq(a: 1)
    end

    it "returns the query" do
      query.select(a: 1).should eql query
    end
  end

  describe "#sort" do

    context "when called for the first time" do

      it "updates the selector to mongo's advanced selector" do
        query.sort(a: 1)
        query.operation.selector.should eq(
          "$query" => selector,
          "$orderby" => { a: 1 }
        )
      end
    end

    context "when called again" do

      it "changes the $orderby" do
        query.sort(a: 1)
        query.sort(a: 2)
        query.operation.selector.should eq(
          "$query" => selector,
          "$orderby" => { a: 2 }
        )
      end
    end

    it "returns the query" do
      query.sort(a: 1).should eql query
    end
  end

  describe "#explain" do

    before do
      session.should_receive(:simple_query).with(query.operation)
    end

    context "when a sort exists" do

      before do
        query.sort(_id: 1)
      end

      it "updates to a mongo advanced selector" do
        query.explain
        query.operation.selector.should eq(
          "$query" => selector,
          "$explain" => true,
          "$orderby" => { _id: 1 }
        )
      end
    end

    context "when no sort exists" do

      it "updates to a mongo advanced selector" do
        query.explain
        query.operation.selector.should eq(
          "$query" => selector,
          "$explain" => true,
          "$orderby" => {}
        )
      end
    end
  end

  describe "#one" do

    it "executes a simple query" do
      session.should_receive(:simple_query).with(query.operation)
      query.one
    end
  end

  describe "#distinct" do

    it "executes a distinct command" do
      database.should_receive(:command).with(
        distinct: collection.name,
        key: "name",
        query: selector
      ).and_return("values" => [ "durran", "bernerd" ])
      query.distinct(:name)
    end
  end

  describe "#count" do

    it "executes a count command" do
      database.should_receive(:command).with(
        count: collection.name,
        query: selector
      ).and_return("n" => 4)

      query.count
    end

    it "returns the count" do
      database.stub(command: { "n" => 4 })

      query.count.should eq 4
    end
  end

  describe "#update" do

    let(:change) do
      Hash[ a: 1 ]
    end

    it "updates the record matching selector with change" do
      session.should_receive(:with, :consistency => :strong).
        and_yield(session)

      session.should_receive(:execute).with do |update|
        update.flags.should eq []
        update.selector.should eq query.operation.selector
        update.update.should eq change
      end

      query.update change
    end
  end

  describe "#update_all" do

    let(:change) do
      Hash[ a: 1 ]
    end

    it "updates all records matching selector with change" do
      query.should_receive(:update).with(change, [:multi])
      query.update_all change
    end
  end

  describe "#upsert" do

    let(:change) do
      Hash[ a: 1 ]
    end

    it "upserts the record matching selector with change" do
      query.should_receive(:update).with(change, [:upsert])
      query.upsert change
    end
  end

  describe "#remove" do

    it "removes the first matching document" do
      session.should_receive(:with, :consistency => :strong).
        and_yield(session)

      session.should_receive(:execute).with do |delete|
        delete.flags.should eq [:remove_first]
        delete.selector.should eq query.operation.selector
      end

      query.remove
    end
  end

  describe "#remove_all" do

    it "removes all matching documents" do
      session.should_receive(:with, :consistency => :strong).
        and_yield(session)

      session.should_receive(:execute).with do |delete|
        delete.flags.should eq []
        delete.selector.should eq query.operation.selector
      end

      query.remove_all
    end
  end

  describe "#each" do

    before do
      session.should_receive(:with).
        with(retain_socket: true).and_return(session)
    end

    it "creates a new cursor" do
      cursor = mock(Moped::Cursor, next: nil)
      Moped::Cursor.should_receive(:new).
        with(session, query.operation).and_return(cursor)

      query.each
    end

    it "yields all documents in the cursor" do
      cursor = Moped::Cursor.allocate
      cursor.stub(:to_enum).and_return([1, 2].to_enum)

      Moped::Cursor.stub(new: cursor)

      query.to_a.should eq [1, 2]
    end

    it "returns an enumerator" do
      cursor = mock(Moped::Cursor)
      Moped::Cursor.stub(new: cursor)

      query.each.should be_a Enumerator
    end
  end
end
