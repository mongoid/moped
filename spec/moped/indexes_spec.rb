require "spec_helper"

describe Moped::Indexes do
  let(:session) { Moped::Session.new ["127.0.0.1:27017"], database: "moped_test" }
  let(:indexes) do
    described_class.new(session.current_database, :users)
  end

  after do
    session.command(deleteIndexes: "users", index: "*")
  end

  describe "#each" do
    before do
      session[:"system.indexes"].insert(ns: "moped_test.users", key: { name: 1 }, name: "name_1")
    end

    it "yields all indexes on the collection" do
      indexes.to_a.should eq \
        session[:"system.indexes"].find(ns: "moped_test.users").to_a
    end
  end

  describe "#[]" do
    before do
      session[:"system.indexes"].insert(ns: "moped_test.users", key: { name: 1 }, name: "name_1")
    end

    it "returns the index with the provided key" do
      indexes[name: 1]["name"].should eq "name_1"
    end
  end

  describe "#create" do
    let(:key) do
      Hash["location.latlong" => "2d", "name" => 1, "age" => -1]
    end

    context "with no options" do
      it "creates an index with a generated name" do
        indexes.create(key)
        indexes[key]["name"].should eq "location.latlong_2d_name_1_age_-1"
      end
    end

    context "with a name provided" do
      it "creates an index with the provided name" do
        indexes.create(key, name: "custom_index_name")
        indexes[key]["name"].should eq "custom_index_name"
      end
    end

    context "with background: true" do
      it "creates an index" do
        indexes.create(key, background: true)
        indexes[key]["background"].should eq true
      end
    end

    context "with dropDups: true" do
      it "creates an index" do
        indexes.create(key, dropDups: true)
        indexes[key]["dropDups"].should eq true
      end
    end

    context "with unique: true" do
      it "creates an index" do
        indexes.create(key, unique: true)
        indexes[key]["unique"].should eq true
      end
    end

    context "with sparse: true" do
      it "creates an index" do
        indexes.create(key, sparse: true)
        indexes[key]["sparse"].should eq true
      end
    end

    context "with v: 0" do
      it "creates an index" do
        indexes.create(key, v: 0)
        indexes[key]["v"].should eq 0
      end
    end

  end

  describe "#drop" do
    before do
      indexes.create name: 1
      indexes.create age: -1
    end

    context "with no key" do
      before do
        indexes.drop
      end

      it "drops all indexes for the collection" do
        indexes[name: 1].should be_nil
        indexes[age: -1].should be_nil
      end
    end

    context "with a key" do
      before do
        indexes.drop(name: 1)
      end

      it "drops the index that matches the key" do
        indexes[name: 1].should be_nil
      end

      it "does not drop other indexes" do
        indexes[age: -1].should_not be_nil
      end
    end

    context "with a key that doesn't exist" do
      it "returns false" do
        indexes.drop(other: 1).should be_false
      end
    end
  end

end
