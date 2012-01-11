require "spec_helper"

describe Moped::Errors do

  describe "OperationFailure" do
    let(:command) do
      Moped::Protocol::Query.allocate
    end

    let(:error_details) do
      { "$err"=>"invalid query", "code"=>12580 }
    end

    let(:error) do
      described_class::OperationFailure.new(command, error_details)
    end

    describe "#initialize" do
      it "stores the command which generated the error" do
        error.command.should eq command
      end

      it "stores the details about the error" do
        error.details.should eq error_details
      end
    end

    describe "#message" do
      it "includes the command that generated the error" do
        error.message.should include command.inspect
      end

      context "when code is included in error details" do
        let(:error_details) do
          { "err" => "invalid query", "code" => 12580 }
        end

        it "includes the code" do
          error.message.should include error_details["code"].to_s
        end

        it "includes the error code reference site" do
          error.message.should include Moped::Errors::ERROR_REFERENCE
        end

        it "includes the error message" do
          error.message.should include error_details["err"].inspect
        end
      end

      context "when err is in the error details" do
        let(:error_details) do
          { "err" => "invalid query" }
        end

        it "includes the error message" do
          error.message.should include error_details["err"].inspect
        end
      end

      context "when $err is in the error details" do
        let(:error_details) do
          { "$err" => "not master" }
        end

        it "includes the error message" do
          error.message.should include error_details["$err"].inspect
        end
      end

      context "when errmsg is in the error details" do
        let(:error_details) do
          { "errmsg" => "invalid query" }
        end

        it "includes the error message" do
          error.message.should include error_details["errmsg"].inspect
        end
      end
    end

  end

  describe "QueryFailure" do
    it "is a kind of OperationFailure" do
      Moped::Errors::QueryFailure.ancestors.should \
        include Moped::Errors::OperationFailure
    end
  end

end
