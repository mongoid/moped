require "spec_helper"

describe Moped::Collection do

  let(:session) do
    mock(Moped::Session)
  end

  let(:database) do
    mock(Moped::Database, session: session, name: "moped")
  end

  let(:collection) do
    described_class.new database, :users
  end

  describe "#initialize" do

    it "stores the database" do
      collection.database.should eq database
    end

    it "stores the collection name" do
      collection.name.should eq :users
    end
  end

  describe "#indexes" do
    it "returns a new indexes instance" do
      collection.indexes.should be_an_instance_of Moped::Indexes
    end
  end

  describe "#drop" do

    it "drops the collection" do
      database.should_receive(:command).with(drop: :users)
      collection.drop
    end
  end

  describe "#find" do

    let(:selector) do
      Hash[ a: 1 ]
    end

    let(:query) do
      mock(Moped::Query)
    end

    it "returns a new Query" do
      Moped::Query.should_receive(:new).
        with(collection, selector).and_return(query)
      collection.find(selector).should eq query
    end

    it "defaults to an empty selector" do
      Moped::Query.should_receive(:new).
        with(collection, {}).and_return(query)
      collection.find.should eq query
    end
  end

  describe "#insert" do

    before do
      session.should_receive(:with, :consistency => :strong).and_yield(session)
      session.stub safe?: false
    end

    context "when passed a single document" do

      it "inserts the document" do
        session.should_receive(:execute).with do |insert|
          insert.documents.should eq [{a: 1}]
        end
        collection.insert(a: 1)
      end
    end

    context "when passed multiple documents" do

      it "inserts the documents" do
        session.should_receive(:execute).with do |insert|
          insert.documents.should eq [{a: 1}, {b: 2}]
        end
        collection.insert([{a: 1}, {b: 2}])
      end
    end
  end
end
