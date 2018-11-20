# neo4j_model.cr - a Neo4j ORM for Crystal

[![Version](https://img.shields.io/github/tag/upspring/neo4j_model.cr.svg?maxAge=360)](https://github.com/upspring/neo4j_model.cr/releases/latest)
[![Build Status](https://travis-ci.org/upspring/neo4j_model.cr.svg?branch=master)](https://travis-ci.org/upspring/neo4j_model.cr)
[![License](https://img.shields.io/github/license/upspring/neo4j_model.cr.svg)](https://github.com/upspring/neo4j_model.cr/blob/master/LICENSE)
<!-- [![Gitter](https://img.shields.io/gitter/room/upspring/neo4j_model.cr.svg)](https://gitter.im/upspring/neo4j_model.cr) -->

Current status: API stabilizing, but minor changes possible. Expecting to reach 1.0 by end of 2018. Give it a try on a new project! Just don't use in production yet.

The goal is a stable and full-featured Neo4j ORM for Crystal. Currently Bolt-only (uses [neo4j.cr](https://github.com/jgaskins/neo4j.cr)). Inspired by ActiveNode/[Neo4j.rb](https://github.com/neo4jrb/neo4j).

Features:

* map Crystal properties to Neo4j node properties
* timestamps: sets created_at property on create and updated_at property on save (if present)
* new, save, reload
* find, limit/skip, order, where (currently exact matches only, will add support for arrays and ranges)
* convenience finders: find_by, find_or_initialize_by, find_or_create_by
* callbacks: before/after save, before/after validation - note: callbacks must return true to continue
* query proxy to allow method chaining (query is not executed until you call `#to_a`, `#count`, or try to access a record)
* associations (has_one, has_many, belongs_to, belongs_to_many), chainable (e.g. actor.movies.genres)
* scopes a la ActiveRecord
* connection pooling ([#1](https://github.com/upspring/neo4j_model.cr/pull/1))

The provided association types do assume/impose a convention on the relationship direction, but I find it easier to think of relationships this way, rather than stick with Neo4j's required yet meaningless direction (the way ActiveNode does with the :in/:out parameter).

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
Neo4jModel.settings.logger = Amber.settings.logger.dup
Neo4jModel.settings.logger.progname = "Neo4jModel"
```

```crystal
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

  scope http2, ->{ where(supports_http2: true) }

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
    true # callbacks can return false/nil to abort/indicate failure (or truthy values to continue execution/indicate success)
  end
end
```

Including Neo4j::Model creates an embedded QueryProxy class that you can call directly as needed to run queries not yet supported by the query builder. For example, if Members are nested under both Organization and User and you need to check both, you could do this:

```crystal
proxy = Member::QueryProxy.new("MATCH (o:Organization)-->(m:Member), (u:User)-->(m:Member)", "RETURN m")
member = proxy.where("o.uuid = $o_uuid AND u.uuid = $u_uuid", o_uuid: org.uuid, u_uuid: user.uuid).limit(1).first?
```

However, now that we have some basic association chaining in place, you can also do it this way, which is slightly clearer:

```crystal
member = org.members.users.where(uuid: user.uuid).return(member: :member)
```

## Roadmap

For 1.0:
* [#2](https://github.com/upspring/neo4j_model.cr/issues/2) adjust API to align with [Granite](https://github.com/amberframework/granite)
* [#3](https://github.com/upspring/neo4j_model.cr/issues/3) expand QueryProxy#where to accept arrays and ranges
* [#4](https://github.com/upspring/neo4j_model.cr/issues/4) add QueryProxy#update_all (set property values on all matched nodes, skipping callbacks)
* API to read/write relationship properties

Future (help wanted):
* more callbacks?
* migrations (to add constraints and indexes)
* more specs
* validations (via annotations?)
* option to use an annotation to designate properties that should not be synchronized with database (in addition to existing leading _ convention)

## Contributing

The safest and easiest way to run the specs is via Docker (and safety is important, because the specs empty the database). `docker-compose up` to start the containers (and Ctrl-C to stop them when you're done). Then use the `bin/guardian-docker` script to start guardian, which will watch all the files in src/ and spec/ and run the test suite when any of them is modified.

1. Fork it (<https://github.com/upspring/neo4j_model.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [anamba](https://github.com/anamba) Aaron Namba ([Upspring](https://github.com/organizations/upspring)) - creator/maintainer
- [jgaskins](https://github.com/jgaskins) Jamie Gaskins - creator/maintainer of [neo4j.cr](https://github.com/jgaskins/neo4j.cr)
