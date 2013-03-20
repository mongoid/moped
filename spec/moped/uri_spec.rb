require "spec_helper"

describe Moped::Uri do

  let(:single) do
    "mongodb://user:pass@localhost:27017/mongoid_test"
  end

  let(:multiple) do
    "mongodb://localhost:27017,localhost:27017/mongoid_test"
  end

  let(:invalid) do
    "invalid://uri/test"
  end

  describe "#database" do

    let(:uri) do
      described_class.new(single)
    end

    it "returns the database name" do
      uri.database.should eq("mongoid_test")
    end
  end

  describe "#hosts" do

    context "when a single node is provided" do

      let(:uri) do
        described_class.new(single)
      end

      it "returns an array with 1 node" do
        uri.hosts.should eq([ "localhost:27017" ])
      end
    end

    context "when multiple nodes are provided" do

      let(:uri) do
        described_class.new(multiple)
      end

      it "returns an array with 2 nodes" do
        uri.hosts.should eq([ "localhost:27017", "localhost:27017" ])
      end
    end
  end

  describe "#invalid" do

    let(:uri) do
      described_class.new(invalid)
    end

    it "raises informative error" do
      lambda { uri }.should raise_exception(Moped::Errors::InvalidMongoURI)
    end
  end

  describe "#options" do

    context "when providing write concern options" do

      context "when providing w=-1" do

        let(:uri) do
          described_class.new("mongodb://127.0.0.1:27017/mongoid_test?w=-1")
        end

        it "sets the write concern options" do
          expect(uri.options).to include(write: { w: -1 })
        end
      end

      context "when providing w=0" do

        let(:uri) do
          described_class.new("mongodb://127.0.0.1:27017/mongoid_test?w=0")
        end

        it "sets the write concern options" do
          expect(uri.options).to include(write: { w: 0 })
        end
      end

      context "when providing w=1" do

        let(:uri) do
          described_class.new("mongodb://127.0.0.1:27017/mongoid_test?w=1")
        end

        it "sets the write concern options" do
          expect(uri.options).to include(write: { w: 1 })
        end
      end

      context "when providing w=n" do

        let(:uri) do
          described_class.new("mongodb://127.0.0.1:27017/mongoid_test?w=3")
        end

        it "sets the write concern options" do
          expect(uri.options).to include(write: { w: 3 })
        end
      end

      context "when providing w=majority" do

        let(:uri) do
          described_class.new("mongodb://127.0.0.1:27017/mongoid_test?w=majority")
        end

        it "sets the write concern options" do
          expect(uri.options).to include(write: { w: :majority })
        end
      end

      context "when providing fsync options" do

        let(:uri) do
          described_class.new("mongodb://127.0.0.1:27017/mongoid_test?fsync=true")
        end

        it "sets the write concern options" do
          expect(uri.options).to include(write: { fsync: true })
        end
      end

      context "when providing wtimeout options" do

        let(:uri) do
          described_class.new("mongodb://127.0.0.1:27017/mongoid_test?wtimeout=10")
        end

        it "sets the write concern options" do
          expect(uri.options).to include(write: { wtimeout: 10 })
        end
      end
    end
  end

  describe "#password" do

    let(:uri) do
      described_class.new(single)
    end

    it "returns the password" do
      uri.password.should eq("pass")
    end
  end

  describe "#to_hash" do

    context "when a user and password are not provided" do

      let(:uri) do
        described_class.new(multiple)
      end

      it "does not include the username and password" do
        uri.to_hash.should eq({
          hosts: [ "localhost:27017", "localhost:27017" ],
          database: "mongoid_test"
        })
      end
    end

    context "when a user and password are provided" do

      let(:uri) do
        described_class.new(single)
      end

      it "includes the username and password" do
        uri.to_hash.should eq({
          hosts: [ "localhost:27017" ],
          database: "mongoid_test",
          username: "user",
          password: "pass"
        })
      end
    end
  end

  describe "#username" do

    let(:uri) do
      described_class.new(single)
    end

    it "returns the userame" do
      uri.username.should eq("user")
    end
  end

  describe "#moped_arguments" do

    let(:simple_url) do
      "mongodb://host2:27018/my_stock_db"
    end

    let(:replica_set_uri) do
      "mongodb://host1:27017,host2:27018/my_replica_set"
    end

    let(:auth) do
      "mongodb://utest:ptest@host1:27017/my_authed_db"
    end

    let(:full_monty) do
      "mongodb://utest:ptest@host1:27017,host2:27018/full_monthy?read=primary&ssl=false&w=1&retry_interval=35&timeout=7"
    end

    it "accepts stock uri" do
      Moped::Session.should_receive(:new).
        with([ "host2:27018" ], database: "my_stock_db")
      Moped::Session.connect(simple_url)
    end

    it "accepts replica set uri" do
      Moped::Session.should_receive(:new).
        with([ "host1:27017" ,"host2:27018" ], database: "my_replica_set")
      Moped::Session.connect(replica_set_uri)
    end

    it "accepts authed uri" do
      login = Struct.new(:MockLogin).new
      login.should_receive(:login).with("utest", "ptest")

      Moped::Session.should_receive(:new).
        with([ "host1:27017" ], :database=>"my_authed_db").
        and_return(login)
      Moped::Session.connect(auth)
    end

    it "accepts full monty" do
      login = Struct.new(:MockLogin).new
      login.should_receive(:login).with("utest", "ptest")

      Moped::Session.should_receive(:new).
        with(
          [ "host1:27017", "host2:27018" ],
          database: "full_monthy",
          read: :primary,
          ssl: false,
          write: { w: 1 },
          retry_interval: 35,
          timeout: 7
        ).and_return(login)
      Moped::Session.connect(full_monty)
    end
  end
end
