# Overview

## 1.2.0 (branch: master)

### New Features

* mongoid/mongoid\#2210 Added `Session#disconnect` which will disconnect all
  nodes in the cluster from their respective database servers. Useful for cases
  where a large number of database connections are being created on separate
  threads and need to be explicitly closed after their work is completed.

* \#33 Added `Session#databases` and `Session#database_names` as a convenience
  for getting all database information for the server.

        session = Moped::Session.new([ "localhost:27017" ])
        session.database_names #=> [ "moped_test" ]
        session.databases #=> { "databases" => [{ "name" => "moped_test" }]}

## 1.1.6 (branch: 1.1.0-stable)

* \#41 `ObjectId.from_time` now only includes the timestamp, no machine or
  process information.

### Resolved Issues

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
