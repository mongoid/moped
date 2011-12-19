require "spec_helper"

describe Moped::Session do
  context "with a single master node" do
    let(:session) { Moped::Session.new "127.0.0.1:27017", database: "moped_test" }

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
  end
end
