require "spec_helper"

describe Moped::Database do
  let(:session) do
    Moped::Session.new %w[127.0.0.1:27017], database: "moped_test"
  end

  describe "constructor" do
    it "works with valid session and database name" do
      Moped::Database.new(session, 'valid_database_name').should be_instance_of(Moped::Database)
    end

    it "blows up with an invalid database name" do
      invalid =
        'invalid database name',
        'invalid.database.name'

      invalid.each do |name|
        expect {
          Moped::Database.new(session, name).should
        }.to raise_error(NameError)
      end
    end
  end
end
