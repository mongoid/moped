# encoding: utf-8
require "spec_helper"

describe Moped::ConnectionPool do

  describe "#with_connection" do

    let(:pool) do
      described_class.new("localhost", 27017, 30, pool_size: 5)
    end

    let(:threads) do
      []
    end

    after do
      threads.map(&:value)
    end

    it "yields to the connection" do
      20.times do
        threads << Thread.new do
          pool.with_connection do |connection|
            connection.should be_a(Moped::Connection)
          end
        end
      end
    end

    it "returns the result of the yield" do
      pool.with_connection do |connection|
        connection.host
      end.should eq("localhost")
    end
  end
end
