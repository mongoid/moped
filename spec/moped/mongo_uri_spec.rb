require "spec_helper"

describe Moped::MongoUri do
  describe "#moped_arguments" do
    let :simple_url do
      "mongodb://host2:27018/my_stock_db"
    end

    let :replica_set_uri do
      "mongodb://host1:27017,host2:27018/my_replica_set"
    end

    let :auth do
      "mongodb://utest:ptest@host1:27017/my_authed_db"
    end

    let :full_monty do
      "mongodb://utest:ptest@host1:27017,host2:27018/full_monthy?consistency=strong&ssl=false&safe=true&retry_interval=35&timeout=7"
    end

    it "accepts stock uri" do
      Moped::Session.should_receive(:new).with(["host2:27018"], {database: "my_stock_db"})
      session = Moped::Session.connect(simple_url)
    end

    it "accepts replica set uri" do
      Moped::Session.should_receive(:new).with(["host1:27017","host2:27018"], {database: "my_replica_set"})
      session = Moped::Session.connect(replica_set_uri)
    end

    it "accepts authed uri" do
      login = Struct.new(:MockLogin).new
      login.should_receive(:login).with("utest", "ptest")

      Moped::Session.should_receive(:new).with(["host1:27017"], {:database=>"my_authed_db"}).and_return(login)
      session = Moped::Session.connect(auth)
    end

    it "accepts full monty" do
      login = Struct.new(:MockLogin).new
      login.should_receive(:login).with("utest", "ptest")

      Moped::Session.should_receive(:new).with(["host1:27017", "host2:27018"], {:database=>"full_monthy", :consistency=> :strong, :ssl=>false, :safe=>true, :retry_interval=>35, :timeout=>7}).and_return(login)
      session = Moped::Session.connect(full_monty)
    end

  end
end