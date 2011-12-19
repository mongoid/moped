require "spec_helper"

describe Moped::Session do
  context "with a single master node" do
    let(:session) { Moped::Session.new "127.0.0.1:27017", database: "moped_test" }

    after do
      session[:people].drop
    end

    it "inserts and queries a single document" do
      id = Moped::BSON::ObjectId.new
      session[:people].insert(_id: id, name: "John")
      john = session[:people].find(_id: id).one
      john["_id"].should eq id
      john["name"].should eq "John"
    end

    it "drops a collection" do
      session[:people].drop
      session.command(count: :people)["n"].should eq 0
      session[:people].insert(name: "John")
      session.command(count: :people)["n"].should eq 1
    end

    it "can be inserted into safely" do
      session.with(safe: true) do |session|
        session[:people].insert(name: "John")["ok"].should eq 1
      end
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

    it "can delete a multiple documents" do
      session[:people].insert([{name: "John"}, {name: "John"}])
      session[:people].find(name: "John").remove_all
      session[:people].find.count.should eq 0
    end
  end
end
