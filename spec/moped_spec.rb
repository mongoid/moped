require "spec_helper"

describe Moped::Session do
  let(:seeds) { "127.0.0.1:27017" }
  let(:options) { Hash[database: "test", safe: true] }
  let(:session) { described_class.new seeds, options }

  describe "#initialize" do
    it "stores the options provided" do
      session.options.should eq options
    end
  end

  describe "#with" do
    let(:new_options) { Hash[database: "test-2"] }

    context "when called with a block" do
      it "yields a session" do
        session.with(new_options) do |new_session|
          new_session.should be_a Moped::Session
        end
      end

      it "yields a new session" do
        session.with(new_options) do |new_session|
          new_session.should_not eql session
        end
      end

      it "merges the old and new session's options" do
        session.with(new_options) do |new_session|
          new_session.options.should eq options.merge(new_options)
        end
      end

      it "does not change the original session's options" do
        original_options = options.dup
        session.with(new_options) do |new_session|
          session.options.should eql original_options
        end
      end
    end

    context "when called without a block" do
      it "returns a session" do
        session.with(new_options).should be_a Moped::Session
      end

      it "returns a new session" do
        session.with(new_options).should_not eql session
      end

      it "merges the old and new session's options" do
        session.with(new_options).options.should eq options.merge(new_options)
      end

      it "does not change the original session's options" do
        original_options = options.dup
        session.with(new_options)
        session.options.should eql original_options
      end
    end
  end

end
