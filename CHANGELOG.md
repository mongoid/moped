# Overview

## 1.3.0 (branch: master)

### New Features

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
