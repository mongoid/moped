require "bundler"
Bundler.require

$:.unshift((Pathname(__FILE__).dirname.parent + "lib").to_s)

require "moped"

# Nodes:
#   db1       40001
#
#   db2       40002
#     - root@rapadura
#     - reader@rapadura (readonly)
#
#   rs1a      40011 (master)
#   rs1b      40012
#   rs1c      40013
#
#   rs2a      40021 (master unknown)
#   rs2b      40022
#   rs2c      40023
