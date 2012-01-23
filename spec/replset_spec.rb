require "spec_helper"

describe "testing" do
  let(:cluster) { Moped::Cluster.new "", false }
  let(:socket) { Moped::Socket.new "", 99999 }
  let(:connection) { Support::MockConnection.new }

  before do
    socket.stub(connection: connection, alive?: true)
  end

  describe "#sync_socket" do
  end
end

__END__

# sequence for single node startup:
#
#   connection failure (node not up)

{"ismaster" => true, "maxBsonObjectSize" => 16777216, "ok" => 1.0}

# sequence for replica set startup pre-initialize:
#
#   connection failure

{"ismaster" => false, "secondary" => false, "info" => "can't get local.system.replset config from self or any seed (EMPTYCONFIG)", "isreplicaset" => true, "maxBsonObjectSize" => 16777216, "ok" => 1.0}

# sequence for replica set startup (master):
#
#   connection failure (node not up)

{"ismaster" => false, "secondary" => false, "info" => "can't get local.system.replset config from self or any seed (EMPTYCONFIG)", "isreplicaset" => true, "maxBsonObjectSize" => 16777216, "ok" => 1.0}

{"setName" => "3ff029114780", "ismaster" => false, "secondary" => true, "hosts" => ["localhost:59246", "localhost:59248", "localhost:59247"], "me" => "localhost:59246", "maxBsonObjectSize" => 16777216, "ok" => 1.0}

{"ismaster" => false, "secondary" => false, "info" => "Received replSetInitiate - should come online shortly.", "isreplicaset" => true, "maxBsonObjectSize" => 16777216, "ok" => 1.0}

{"setName" => "3ff029114780", "ismaster" => true, "secondary" => false, "hosts" => ["localhost:59246", "localhost:59248", "localhost:59247"], "primary" => "localhost:59246", "me" => "localhost:59246", "maxBsonObjectSize" => 16777216, "ok" => 1.0}

# sequence for replica set startup (secondary):
#
#   connection failure (node not up)

{"ismaster" => false, "secondary" => false, "info" => "can't get local.system.replset config from self or any seed (EMPTYCONFIG)", "isreplicaset" => true, "maxBsonObjectSize" => 16777216, "ok" => 1.0}

{"setName" => "3fef4842b608", "ismaster" => false, "secondary" => false, "hosts" => ["localhost:61085", "localhost:61086", "localhost:61084"], "me" => "localhost:61085", "maxBsonObjectSize" => 16777216, "ok" => 1.0}

{"setName" => "3fef4842b608", "ismaster" => false, "secondary" => false, "hosts" => ["localhost:61085", "localhost:61086", "localhost:61084"], "primary" => "localhost:61084", "me" => "localhost:61085", "maxBsonObjectSize" => 16777216, "ok" => 1.0}

{"setName" => "3fef4842b608", "ismaster" => false, "secondary" => true, "hosts" => ["localhost:61085", "localhost:61086", "localhost:61084"], "primary" => "localhost:61084", "me" => "localhost:61085", "maxBsonObjectSize" => 16777216, "ok" => 1.0}

__END__

describe Moped::Cluster do
  context "when connecting to a single seed" do
    context "and the seed is down"

    context "and that seed is primary" do
      it "finds the primary node"

      it "adds the secondary to the dynamic seeds"
      it "adds the arbiter to the dynamic seeds"
    end

    context "and that seed is secondary" do
      it "finds the secondary node"

      it "adds the primary to the dynamic seeds"
      it "adds the arbiter to the dynamic seeds"
    end

    context "and that seed is an arbiter" do
      it "adds the primary to the dynamic seeds"
      it "adds the secondary to the dynamic seeds"
    end
  end

  context "when connected to a single seed" do
    context "and that seed goes down" do
      it "is able to resync from discovered nodes"
    end
  end

  context "when connecting to a replica set" do
    context "and the replica set is not initiated"
    context "and the replica set is partially initiated"
    context "and there is no master node"
    context "and there is no secondary node"
  end

  context "when connected to a replica set" do
    context "and the primary node goes down" do
      it "issues reads to the secondary"
    end

    context "and the primary node changes"

    context "and the secondary node goes down" do
      it "issues inserts to the primary"
      it "issues reads to the primary"
    end
  end

end
