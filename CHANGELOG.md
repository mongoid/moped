# Overview

## 1.3.0

### New Features

* \#114 Moped now accepts connecting with a URI. (Christopher Winslett)

        Moped::Session.connect("mongodb://localhost:27017/my_db")

* \#79 Tailable cursors are now supported. These are just Ruby `Enumerators` that
  keep the cursor open until the next document appears. The cursor will be closed
  when it becomes "dead".

        enumerator = session[:users].find.tailable.each
        enumerator.next # Will stay open until next doc.

* mongoid/mongoid\#2460 Moped now makes the connection timeout configurable
  by passing a `:timeout` option to the session. This defaults to 5 seconds.

        Moped::Session.new([ "node1:27017", "node2:27017" ], timeout: 5)

* \#49 Support for the 2.2 aggregation framework is included. (Rodrigo Saito)

        session[:users].aggregate({
          "$group" => {
            "_id" => "$city",
            "totalpop" => { "$sum" => "$pop" }
          }
        })

* \#42 Moped now supports SSL connections to MongoDB. Provide the `ssl: true`
  option when creating a new `Session`. This is currently experimental.

        Moped::Session.new([ "ssl.mongohq.com:10004" ], ssl: true)

### Resolved Issues

* \#110 Handle timeout errors with SSL connections gracefully and mark nodes as
  down without failing any other queries.

* \#109 Moped reauthorizes on "db assertion failures" with commands that have
  an unauthorized assertion code in the reply.

## 1.2.9

* Moped now ensures that when reading bytes from the socket that it continues
  to read until the requested number of bytes have been received. In the case
  of getting `nil` back it will raise a `ConnectionFailure` and go through the
  normal failover motions.

## 1.2.8

### Resolved Issues

* \#108 Connection drops that would result in a `nil` response on socket read or
  a `SocketError` now re-raise a `ConnectionFailure` error which causes the
  replica set to go through it's failover behavor with node refreshing.

* \#104 `Query#explain` now respects limit.

* \#103 Port defaults to 27017 instead of zero if not provided. (Chris Winslett)

* \#100 Fix duplicate object id potential issue for JRuby. (Tim Olsen)

* \#97 Propagate node options to newly discovered nodes. (Adam Lebsack)

* \#91 Added more graceful replica set handling when safe mode is enabled
  and replica sets were reconfigured. (Nicolas Viennot)

* \#90 Include arbiters in the list of nodes to disconnect. (Matt Parlane)

## 1.2.7

### Resolved Issues

* \#87 `Moped::BSON::ObjectId.legal?` now returns true for object ids.

* \#85 Allow `===` comparisons with object ids to check for equality of the
  underlying string. (Bob Aman)

* \#84 Query hints are no longer wiped on explain.

* \#60/\#80 Moped now gracefully handles replica set reconfig and crashes of the
  primary and secondary. By default, the node list will be refreshed every
  second and the operation will be retried up to 30 times. This is configurable
  by setting the `:max_retries` and `:retry_interval` options on the session.

        Moped::Session.new(
          [ "node1:27017", "node2:27017" ],
          retry_interval: 0.5, max_retries: 45
        )

## 1.2.6

### Resolved Issues

* mongoid/mongoid\#2430 Don't include $orderby criteria in update calls.

## 1.2.5

### Resolved Issues

* \#76 Fixed typo in database check on Node. (Mathieu Ravaux)

* \#75 Ensure that `Errno::EHOSTUNREACH` is also handled with other socket errors.

## 1.2.2

### Resolved Issues

* \#73 Raise a `Moped::Errors::CursorNotFound` on long running queries where
  the cursor was killed by the server. (Marius Podwyszynski)

* \#72 Reauthenticate properly when an `rs.stepDown()` occurs in the middle of
  cursor execution.

* \#71 When DNS cannot resolve on node initialization, the node will be flagged
  as down instead of raising a `SocketError`. On subsequent refreshes Moped will
  attempt to resolve the DNS again to determine if the node can be brought up.

## 1.2.1

### Resolved Issues

* \#63 `Database#collection_names` now returns collections with "system" in
  the name that aren't core MongoDB system collections. (Hans Hasselberg)

* \#62 Ensure `Connection#alive?` returns false if I/O errors occur. (lowang)

* \#59 Use the current database, not admin, for `getLastError` commands.
  (Christopher Winslett)

* \#57 Ensure collection name is a string for all operations.

* \#50 Fixed connection issues when connection is disconnected mid call.
  (Jonathan Hyman)

## 1.2.0

### New Features

* mongoid/mongoid\#2251 Allow `continue_on_error` option to be provided to
  inserts.

* mongoid/mongoid\#2210 Added `Session#disconnect` which will disconnect all
  nodes in the cluster from their respective database servers. Useful for cases
  where a large number of database connections are being created on separate
  threads and need to be explicitly closed after their work is completed.

* \#33 Added `Session#databases` and `Session#database_names` as a convenience
  for getting all database information for the server.

        session = Moped::Session.new([ "localhost:27017" ])
        session.database_names #=> [ "moped_test" ]
        session.databases #=> { "databases" => [{ "name" => "moped_test" }]}

## 1.1.6

### Resolved Issues

* \#45 When providing database names with invalid characters in them, Moped
  will now raise an `InvalidDatabaseName` error.

* \#41 `ObjectId.from_time` now only includes the timestamp, no machine or
  process information.

## 1.1.5

### Resolved Issues

* \#44 Fixed order of parameters for loading timestamps. (Ralf Kistner)

* \#40 Fix explain to return correct number of scanned documents and time.

## 1.1.3

### Resolved Issues

* Queries now can be duped/cloned and be initialized properly.

## 1.1.2

### Resolved Issues

* \#37 Use `TCP_NODELAY` for socket options. (Nicolas Viennot)

## 1.1.1

### Resolved Issues

* mongoid/mongoid\#2175 Fixed sorting by object ids.

## 1.1.0

### Resolved Issues

* \#29 Fixed endian directives order. Moped will now work properly on
  all architectures. This removes support for MRI 1.9.2. (Miguel Herranz)

### Resolved Issues

## 1.0.1

* mongoid/mongoid\#2175 Fixed sorting by object ids.

* \#28 `BSON::Binary` and `BSON::ObjectId` now have readable `to_s` and
  `inspect` methods. (Ara Howard)

### Resolved Issues
