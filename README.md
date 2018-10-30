# neo4j_model

Current status: Very rough, do not use (yet?). Also note that I am very new to Crystal (coming over from Ruby).

The goal for now is to layer just enough property and association functionality on top of [neo4j.cr](https://github.com/jgaskins/neo4j.cr) so that I can build a simple PoC app that talks to an existing database.

Implemented so far:

* Map Crystal properties to Neo4J node properties
* find, where (greatly simplified, exact attribute matches only)
* new, save, reload
* sets created_at property on create and updated_at property on save (if present)
* simple associations (has_one, has_many, belongs_to, belongs_to_many) - NOTE: read-only at present

The association types do assume/impose a convention on the relationship direction, but I find it easier to think of relationships this way, rather than stick with Neo4j's required yet meaningless direction (the way ActiveNode does with the :in/:out parameter).

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

class Server
  include Neo4j::Model

  has_many Website, reltype: :HOSTS # adds .websites
  has_many Website, name: :inactive_websites, reltype: :USED_TO_HOST # adds .inactive_websites

  property name : String?
  property created_at : Time?
  property updated_at : Time?
end

class Website
  include Neo4j::Model

  belongs_to Server, reltype: :HOSTS

  property _internal : Bool # properties starting with _ will not be synchronized with database

  property name : String?
  property size_bytes : Integer?
  property size_updated_at : Time?
  property supports_http2 : Bool = false
  property nameservers : Array(String) = [] of String # defining it as an Array triggers the auto-serializer
  property some_hash : Hash(String, String)? # hashes ought to work too, but... not tested yet
  property created_at : Time? = Time.utc_now
  property updated_at : Time? = Time.utc_now
end
```

## TODO

* make associations writable and queryable
* make relationship properties writable (probably via custom rel class, similar to ActiveRel)
* callbacks
* validations
* query proxy to support chaining (especially chaining of associations)
* scopes

## Contributing

1. Fork it (<https://github.com/upspring/neo4j_model.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [anamba](https://github.com/anamba) Aaron Namba ([Upspring](https://github.com/organizations/upspring)) - creator, maintainer
