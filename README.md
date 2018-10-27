# neo4j_model

Very rough, do not use (yet?). I am very new to Crystal (coming over from Ruby).

The idea is to layer on just enough functionality on top of neo4j.cr so that I can build simple model classes for a PoC app.

Implemented so far:

* Map Crystal properties to Neo4J node properties
* find, where (greatly simplified, exact attribute matches only)
* new, save, reload

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  neo4j_model:
    github: upspring/neo4j_model.cr
```

## Usage

```crystal
require "neo4j_model"

class Website
  include Neo4j::Model

  property name : String?
  property size_bytes : Integer?
  property size_updated_at : Time?
  property supports_http2 : Bool = false
  property nameservers : Array(String) = [] of String # defining it as an Array triggers the auto-serializer
  property some_hash : Hash(String, String)? # hashes ought to work too, but... not tested yet
```

## TODO

* set created_at and updated_at timestamps on save (if present)

## Contributing

1. Fork it (<https://github.com/upspring/neo4j_model.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [anamba](https://github.com/anamba) Aaron Namba ([Upspring](https://github.com/organizations/upspring)) - creator, maintainer
