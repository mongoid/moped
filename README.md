# Moped

Moped is MongoDB driver for Ruby, which exposes a simple, elegant, and (most
importantly) fast and well tested API.

## Overview

### Replica Sets

Moped offers automated syncing with replica sets -- discovering available
primary and secondary nodes and providing automatic failover when a node
becomes unavailable.

## Example

    db = Moped::Session.new "127.0.0.1:27017", database: "moped"
    db.drop
    db[:people].insert([{ name: "John" }, { name: "Mary" }])
    db[:people].find.sort(name: -1).first # => { name: "Mary" }
    db[:people].find(name: "John").update(name: "Jonathan")

    3.times.map do |i|
      Thread.new do
        db[:people].insert(seq: i)
      end
    end.each &:join

    db.with(safe: true) do |db|
      db.insert(name: "Sue")
    end
