require "spec_helper"

describe Moped::Logging do
  let(:config) do
    Module.new { extend Moped::Logging }
  end
  let(:logger) { mock(Logger) }

  describe ".rails_logger" do
    context "when Rails is present" do
      let(:rails) { Class.new }

      before do
        Object.const_set :Rails, rails
      end

      after do
        Object.send(:remove_const, :Rails)
      end

      context "and it defines logger" do
        before do
          rails.stub(logger: logger)
        end

        it "returns the logger" do
          config.rails_logger.should eq logger
        end
      end

      context "but does not define logger" do
        it "returns false" do
          config.rails_logger.should be_false
        end
      end

    end
  end

  describe ".default_logger" do
    it "returns a new logger instance" do
      config.default_logger.should be_a_kind_of Logger
    end

    it "sets the log level to info" do
      config.default_logger.level.should eq Logger::INFO
    end
  end

  describe ".logger" do
    context "when a rails logger is available" do
      before do
        config.stub(rails_logger: logger)
      end

      it "returns the rails logger" do
        config.logger.should eq logger
      end
    end

    context "when a rails logger is not available" do
      before do
        config.stub(rails_logger: nil)
        config.stub(default_logger: logger)
      end

      it "returns the default logger" do
        config.logger.should eq logger
      end
    end

    context "when the logger is set to nil" do
      before do
        config.logger = nil
      end

      it "returns nil" do
        config.logger.should be_nil
      end
    end
  end

end
