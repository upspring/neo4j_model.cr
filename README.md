# neo4j_model.cr

Current status: Give it a try! Just don't use in production. There's no test suite yet and I am very new to Crystal (coming over from Ruby).

The goal for now is to layer just enough property and association functionality on top of [neo4j.cr](https://github.com/jgaskins/neo4j.cr) so that I can build a simple PoC app that talks to an existing database.

Implemented so far:

* map Crystal properties to Neo4j node properties
* timestamps: sets created_at property on create and updated_at property on save (if present)
* new, save, reload
* find, where (greatly simplified, exact matches only), limit, order
* for convenience: find_by, find_or_initialize_by, find_or_create_by
* before_save/after_save callbacks (more coming) - note: callbacks must return true to continue
* query proxy to allow method chaining (query is not executed until you try to access a record)
* simple associations (has_one, has_many, belongs_to, belongs_to_many) - writable (all nodes must be persisted first)
* scopes a la ActiveRecord

The provided association types do assume/impose a convention on the relationship direction, but I find it easier to think of relationships this way, rather than stick with Neo4j's required yet meaningless direction (the way ActiveNode does with the :in/:out parameter).

One major N.B. re: associations: Currently, assigning to has_one or belongs_to associations, the changes take place immediately (i.e. without saving). This MAY CHANGE in the future to require a save. There will also be a similar name_ids = [ id1, id2 ] to make it easier to incorporate the has_many and belongs_to_many associations into forms.

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

  has_many Website, rel_type: :HOSTS # adds .websites
  has_many Website, name: :inactive_websites, rel_type: :USED_TO_HOST # adds .inactive_websites

  property name : String?
  property created_at : Time? = Time.utc_now
  property updated_at : Time? = Time.utc_now
end
```

```crystal
class Website
  include Neo4j::Model

  belongs_to Server, rel_type: :HOSTS

  before_save :generate_api_key

  scope http2, -> { where(supports_http2: true) }

  property _internal : Bool # properties starting with _ will not be synchronized with database

  property name : String?
  property api_key : String?
  property size_bytes : Integer?
  property size_updated_at : Time?
  property supports_http2 : Bool = false
  property nameservers : Array(String) = [] of String # defining it as an Array triggers the auto-serializer
  property some_hash : Hash(String, String)? # hashes ought to work too, but... not tested yet
  property created_at : Time? = Time.utc_now # will be set on create
  property updated_at : Time? = Time.utc_now # will be set on update

  def generate_api_key
    @api_key ||= UUID.random.to_s
  end
end
```

Including Neo4j::Model creates an embedded QueryProxy class that you can call directly as needed to do unusual matches/returns. For example, if Members are nested under both Organization and User and you need to check both:

```crystal
proxy = Member::QueryProxy.new("MATCH (o:Organization)-->(m:Member), (u:User)-->(m:Member)", "RETURN m")
proxy.where("o.uuid = $o_uuid AND u.uuid = $u_uuid", o_uuid: org.uuid, u_uuid: user.uuid).limit(1).first?
```

## TODO

* specs!
* expand #where to accept arrays and ranges
* make relationship properties writable (probably via custom rel class, similar to ActiveRel)
* more callbacks
* migrations (for constraints and indexes)
* validations

## Contributing

1. Fork it (<https://github.com/upspring/neo4j_model.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [anamba](https://github.com/anamba) Aaron Namba ([Upspring](https://github.com/organizations/upspring)) - creator, maintainer
