require "spec_helper"

describe Moped::ReadPreference::Selectable do

  describe "#query_options" do

    let(:preference) do
      Class.new do
        include Moped::ReadPreference::Selectable
      end.new
    end

    context "when the options have flags" do

      let(:options) do
        preference.query_options(flags: [ :tailable ])
      end

      it "appends the slave_ok option" do
        expect(options).to eq(flags: [ :tailable, :slave_ok ])
      end
    end

    context "when the options do not have flags" do

      let(:options) do
        preference.query_options({})
      end

      it "adds the slave_ok option" do
        expect(options).to eq(flags: [ :slave_ok ])
      end
    end
  end
end
