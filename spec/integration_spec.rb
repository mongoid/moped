# encoding: utf-8

require "spec_helper"

describe Moped::Session do
  context "with a single master node" do
    let(:session) { Moped::Session.new ["127.0.0.1:27017"], database: "moped_test" }

    after do
      session[:people].drop if session[:people].find.count > 0
      session.cluster.servers.each(&:close)
    end

    it "inserts and queries a single document" do
      id = Moped::BSON::ObjectId.new
      session[:people].insert(_id: id, name: "John")
      john = session[:people].find(_id: id).one
      john["_id"].should eq id
      john["name"].should eq "John"
    end

    it "inserts and queries on utf-8 data" do
      id = Moped::BSON::ObjectId.new
      doc = {
        "_id" => id,
        "gültig" => "1",
        "1" => "gültig",
        "2" => :"gültig",
        "3" => ["gültig"],
        "4" => /gültig/
      }
      session[:people].insert(doc)
      session[:people].find(_id: id).one.should eq doc
    end

    it "can explain a query" do
      id = Moped::BSON::ObjectId.new
      session[:people].find(_id: id).explain["cursor"].should eq("BasicCursor")
    end

    it "can explain a query with a sort" do
      id = Moped::BSON::ObjectId.new
      query = session[:people].find(_id: id)
      query.sort(_id: 1).explain["cursor"].should eq("BasicCursor")
    end

    it "drops a collection" do
      session.command(count: :people)["n"].should eq 0
      session[:people].insert(name: "John")
      session.command(count: :people)["n"].should eq 1
      session[:people].drop
      session.command(count: :people)["n"].should eq 0
    end

    it "can be inserted into safely" do
      session.with(safe: true) do |session|
        session[:people].insert(name: "John")["ok"].should eq 1
      end
    end

    it "raises an error on a failed insert in safe mode" do
      session.with(safe: true) do |session|
        lambda do
          session[:people].insert("$invalid" => nil)
        end.should raise_exception(Moped::Errors::OperationFailure)
      end
    end

    it "can sort documents" do
      session[:people].insert([{name: "John"}, {name: "Mary"}])
      session[:people].find.sort(_id: -1).first["name"].should eq "Mary"
    end

    it "can update documents" do
      id = Moped::BSON::ObjectId.new
      session[:people].insert(_id: id, name: "John")
      mary = session[:people].find(_id: id).one
      mary["name"].should eq "John"
      session[:people].find(_id: id).update(name: "Mary")
      mary = session[:people].find(_id: id).one
      mary["_id"].should eq id
      mary["name"].should eq "Mary"
    end

    it "can update documents safely" do
      id = Moped::BSON::ObjectId.new
      session[:people].insert(_id: id, name: "John")
      mary = session[:people].find(_id: id).one
      mary["name"].should eq "John"
      session.with(safe: true) do |session|
        session[:people].find(_id: id).update(name: "Mary")["ok"].should eq 1
      end
    end

    it "can update multiple documents" do
      session[:people].insert([{name: "John"}, {name: "Mary"}])
      session[:people].find.update_all("$set" => { "last_name" => "Unknown" })

      session[:people].find.sort(_id: -1).first["last_name"].should eq "Unknown"
      session[:people].find.sort(_id: 1).first["last_name"].should eq "Unknown"
    end

    it "can upsert documents" do
      session[:people].find.upsert(name: "Mary")
      mary = session[:people].find(name: "Mary").one
      mary["name"].should eq "Mary"
    end

    it "can delete a single document" do
      session[:people].insert([{name: "John"}, {name: "John"}])
      session[:people].find(name: "John").remove
      session[:people].find.count.should eq 1
    end

    it "can delete a single document safely" do
      session[:people].insert([{name: "John"}, {name: "John"}])
      session.with(safe: true) do |session|
        session[:people].find(name: "John").remove["ok"].should eq 1
      end
      session[:people].find.count.should eq 1
    end

    it "can delete a multiple documents" do
      session[:people].insert([{name: "John"}, {name: "John"}])
      session[:people].find(name: "John").remove_all
      session[:people].find.count.should eq 0
    end

    it "can retrieve multiple documents with fixed limit" do
      session[:people].insert([{name: "John"}, {name: "Mary"}])
      john, mary = session[:people].find.limit(-2).sort(name: 1).to_a
      john["name"].should eq "John"
      mary["name"].should eq "Mary"
    end

    it "can retrieve distinct values" do
      session[:people].insert([{name: "John"}, {name: "Mary"}])
      values = session[:people].find.distinct(:name)
      values.should eq [ "John", "Mary" ]
    end

    it "can retrieve no documents" do
      session[:people].find.limit(-2).sort(name: 1).to_a.should eq []
    end

    it "can limit a result set" do
      documents = 100.times.map { { _id: Moped::BSON::ObjectId.new } }
      session[:people].insert(documents)
      session[:people].find.limit(20).to_a.length.should eq 20
    end

    it "does not leave open cursors" do
      documents = 100.times.map { { _id: Moped::BSON::ObjectId.new } }
      session[:people].insert(documents)
      session[:people].find.limit(20).to_a.length.should eq 20
      status = session.command serverStatus: 1
      status["cursors"]["totalOpen"].should eq 0
    end

    it "can retrieve large result sets" do
      documents = 1000.times.map do
        { _id: Moped::BSON::ObjectId.new }
      end
      session[:people].insert(documents)
      session[:people].find.to_a.length.should eq 1000
    end

    it "can have multiple connections" do
      status = session.command serverStatus: 1
      count = status["connections"]["current"]
      new_session = session.new
      status = new_session.command serverStatus: 1
      status["connections"]["current"].should eq count + 1
    end
  end
end
