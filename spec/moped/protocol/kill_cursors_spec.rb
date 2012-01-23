require "spec_helper"

describe Moped::Protocol::KillCursors do

  let(:kill_cursors) do
    described_class.allocate
  end

  describe ".fields" do
    it "matches the specification's field list" do
      described_class.fields.should eq [
        :length,
        :request_id,
        :response_to,
        :op_code,
        :reserved,
        :number_of_cursor_ids,
        :cursor_ids
      ]
    end
  end

  describe "#initialize" do
    let(:kill_cursors) do
      described_class.new [123, 321]
    end

    it "sets the cursor ids" do
      kill_cursors.cursor_ids.should eq [123, 321]
    end

    it "sets the number of cursor ids" do
      kill_cursors.number_of_cursor_ids.should eq 2
    end

    context "when request id option is supplied" do
      let(:kill_cursors) do
        described_class.new [123, 321], request_id: 123
      end

      it "sets the request id" do
        kill_cursors.request_id.should eq 123
      end
    end
  end

  describe "#op_code" do
    it "should eq 2007" do
      kill_cursors.op_code.should eq 2007
    end
  end

end
