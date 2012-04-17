require "spec_helper"

describe Moped::Session do
  let(:session) do
    Moped::Session.new %w[127.0.0.1:27017], database: "moped_test"
  end

  describe "#use" do
    it "changes the current database" do
      session.use "moped_test_2"
      session.command(dbStats: 1)["db"].should eq "moped_test_2"
    end
  end

  describe "#with" do
    context "when called with a block" do
      it "returns the value from the block" do
        session.with { :value }.should eq :value
      end

      it "yields a session with the provided options" do
        session.with(safe: true) do |safe|
          safe.options[:safe].should eq true
        end
      end

      it "does not modify the original session" do
        session.with(database: "other") do |safe|
          session.options[:database].should eq "moped_test"
        end
      end
    end

    context "when called without a block" do
      it "returns a session with the provided options" do
        safe = session.with(safe: true)
        safe.options[:safe].should eq true
      end

      it "does not modify the original session" do
        other = session.with(database: "other")
        session.options[:database].should eq "moped_test"
      end
    end
  end

  describe "#drop" do
    it "drops the current database" do
      session.with(database: "moped_test_2") do |session|
        session.drop.should eq("dropped" => "moped_test_2", "ok" => 1)
      end
    end
  end

  describe "#command" do
    it "runs the command on the current database" do
      session.with(database: "moped_test_2") do |session|
        session.command(dbStats: 1)["db"].should eq "moped_test_2"
      end
    end
  end

end
