require "spec_helper"

describe Moped::BSON::Code do

  describe "#code" do
    it "returns the code from initializer" do
      Moped::BSON::Code.new("function() {}").code.should eq "function() {}"
    end
  end

  describe "#scope" do
    context "by default" do
      it "returns nil" do
        Moped::BSON::Code.new("").scope.should eq nil
      end
    end

    context "when provided" do
      it "returns the value" do
        Moped::BSON::Code.new("", {}).scope.should eq({})
      end
    end
  end

  describe "#scoped?" do
    context "when a scope is not provided" do
      it "returns true" do
        Moped::BSON::Code.new("").should_not be_scoped
      end
    end

    context "when a scope is provided" do
      it "returns true" do
        Moped::BSON::Code.new("", {}).should be_scoped
      end
    end
  end

  describe "#==" do
    let(:code) { "function() {}" }
    let(:scope) { { a: 1 } }

    context "when code and scope are the same" do
      it "returns true" do
        Moped::BSON::Code.new(code, scope).should == Moped::BSON::Code.new(code, scope)
      end
    end

    context "when code is different" do
      it "returns false" do
        Moped::BSON::Code.new(code, scope).should_not == Moped::BSON::Code.new("", scope)
      end
    end

    context "when scope is different" do
      it "returns false" do
        Moped::BSON::Code.new(code, scope).should_not == Moped::BSON::Code.new(code, {})
      end
    end

    context "when other is not Moped::BSON::Code instance" do
      it "returns false" do
        Moped::BSON::Code.new(code).should_not == nil
      end
    end

  end

  describe "#eql?" do
    let(:code) { "function() {}" }
    let(:scope) { { a: 1 } }

    context "when code and scope are the same" do
      it "returns true" do
        Moped::BSON::Code.new(code, scope).should eql Moped::BSON::Code.new(code, scope)
      end
    end

    context "when code is different" do
      it "returns false" do
        Moped::BSON::Code.new(code, scope).should_not eql Moped::BSON::Code.new("", scope)
      end
    end

    context "when scope is different" do
      it "returns false" do
        Moped::BSON::Code.new(code, scope).should_not eql Moped::BSON::Code.new(code, {})
      end
    end

    context "when other is not Moped::BSON::Code instance" do
      it "returns false" do
        Moped::BSON::Code.new(code).should_not eql nil
      end
    end
  end

  describe "#hash" do
    let(:code) { "function() {}" }
    let(:scope) { { a: 1 } }

    context "when code and scope are the same" do
      it "returns true" do
        Moped::BSON::Code.new(code, scope).hash.should eq Moped::BSON::Code.new(code, scope).hash
      end
    end

    context "when code is different" do
      it "returns false" do
        Moped::BSON::Code.new(code, scope).hash.should_not eq Moped::BSON::Code.new("", scope).hash
      end
    end

    context "when scope is different" do
      it "returns false" do
        Moped::BSON::Code.new(code, scope).hash.should_not eq Moped::BSON::Code.new(code, {}).hash
      end
    end

    context "when other is not Moped::BSON::Code instance" do
      it "returns false" do
        Moped::BSON::Code.new(code).hash.should_not eq nil.hash
      end
    end
  end

end
