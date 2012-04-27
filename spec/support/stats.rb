module Support

  # Module for recording operations.
  #
  #   Support::Stats.install!
  #
  #   stats = Support::Stats.collect do
  #     session.with(safe: true)[:users].insert({})
  #   end
  #
  #   ops = stats["127.0.0.1:27017"]
  #   ops.size # => 2
  #   ops[0].class # => Moped::Protocol::Insert
  #   ops[1].class # => Moped::Protocol::Command
  #
  module Stats
    extend self

    def record(node, operations)
      key = if node.primary?
        :primary
      elsif node.secondary?
        :secondary
      else
        :other
      end

      @stats[key].concat(operations) if @stats
    end

    def collect
      @stats = Hash.new { |hash, key| hash[key] = [] }
      yield
      @stats
    ensure
      @stats = nil
    end

    def install!
      Moped::Node.class_eval <<-EOS
        alias _logging logging

        def logging(operations, &block)
          Support::Stats.record(self, operations)
          _logging(operations, &block)
        end
      EOS
      @stats = nil
    end

  end
end
