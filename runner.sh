#!/bin/bash

tmpdir=$PWD/tmp
mongod=$(which mongod)
mongos=$(which mongos)

start() {
  mkdir -p $tmpdir
  cd $tmpdir
  mkdir -p db1 db2 rs1a rs1b rs1c rs2a rs2b rs2c cfg1 cfg2
  cd ..

  launchctl submit -l com.moped.mongodb.db1  -- $mongod --nojournal --smallfiles --nssize=1 --shardsvr        --dbpath $tmpdir/db1 --port 40001
  launchctl submit -l com.moped.mongodb.db2  -- $mongod --nojournal --smallfiles --nssize=1 --shardsvr --auth --dbpath $tmpdir/db2 --port 40002

  launchctl submit -l com.moped.mongodb.rs1a -- $mongod --oplogSize 1 --nojournal --smallfiles --nssize=1 --shardsvr --replSet rs1 --dbpath $tmpdir/rs1a --port 40011
  launchctl submit -l com.moped.mongodb.rs1b -- $mongod --oplogSize 1 --nojournal --smallfiles --nssize=1 --shardsvr --replSet rs1 --dbpath $tmpdir/rs1b --port 40012
  launchctl submit -l com.moped.mongodb.rs1c -- $mongod --oplogSize 1 --nojournal --smallfiles --nssize=1 --shardsvr --replSet rs1 --dbpath $tmpdir/rs1c --port 40013

  launchctl submit -l com.moped.mongodb.rs2a -- $mongod --oplogSize 1 --nojournal --smallfiles --nssize=1 --shardsvr --replSet rs2 --dbpath $tmpdir/rs2a --port 40021
  launchctl submit -l com.moped.mongodb.rs2b -- $mongod --oplogSize 1 --nojournal --smallfiles --nssize=1 --shardsvr --replSet rs2 --dbpath $tmpdir/rs2b --port 40022
  launchctl submit -l com.moped.mongodb.rs2c -- $mongod --oplogSize 1 --nojournal --smallfiles --nssize=1 --shardsvr --replSet rs2 --dbpath $tmpdir/rs2c --port 40023

  launchctl submit -l com.moped.mongodb.cfg1 -- $mongod --nojournal --smallfiles --nssize=1 --configsvr --dbpath $tmpdir/cfg1 --port 40101
  launchctl submit -l com.moped.mongodb.cfg2 -- $mongod --nojournal --smallfiles --nssize=1 --configsvr --dbpath $tmpdir/cfg2 --port 40102

  launchctl submit -l com.moped.mongodb.s1   -- $mongos --configdb 127.0.0.1:40101 --bind_ip=127.0.0.1 --port 40201 --chunkSize 1
  launchctl submit -l com.moped.mongodb.s2   -- $mongos --configdb 127.0.0.1:40102 --bind_ip=127.0.0.1 --port 40202 --chunkSize 1

  mongo --nodb spec/support/init.js
}

stop() {
  if [ -d $tmpdir ]; then
    echo "Shutting down test cluster..."
    for node in $(launchctl list | grep com.moped.mongodb. | cut -f 3); do
      launchctl remove "$node"
    done
    rm -rf $tmpdir
  fi
}

case "$1" in

  start)
    start
    ;;

  stop)
    stop
    ;;

esac
