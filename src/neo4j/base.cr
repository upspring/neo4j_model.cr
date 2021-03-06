require "neo4j"
require "uuid"
require "pool/connection"

module Neo4j
  module Model
    ConnectionPool = ::ConnectionPool(Bolt::Connection).new(capacity: Neo4jModel.settings.pool_size) do
      Bolt::Connection.new(Neo4jModel.settings.neo4j_bolt_url, ssl: false)
    end

    def uuid : String
      @_uuid
    end

    # id works differently from uuid because sometimes presence of id is used like #persisted?
    # but in our case, for various reasons, we assign a uuid even before the node is created
    def id : String?
      persisted? ? @_uuid : nil
    end

    def label : String
      self.class.label
    end

    macro included
      # allows == and === comparisions
      def_equals(@_uuid)

      # allows use as hash key and makes Array#uniq work
      def hash
        @_uuid.hash
      end

      def rel : Relationship?
        @_rel
      end

      # use leading underscore to indicate a property/ivar that should *not* be persisted to neo4j
      @[JSON::Field(ignore: true)]
      property _persisted : Bool = false
      @[JSON::Field(ignore: true)]
      property _uuid : String = UUID.random.to_s # special because it is persisted on create, but never on update
      @[JSON::Field(ignore: true)]
      property _node : Neo4j::Node = Neo4j::Node.new(0_i64, Array(String).new, Hash(String, Neo4j::Value).new) # snapshot of db node
      @[JSON::Field(ignore: true)]
      property _rel : Relationship?

      # override if you want to use a different label
      class_getter label : String = "{{@type.name}}"

      def {{@type.id}}.with_connection
        Neo4jModel.settings.mutex.synchronize do
          if Neo4jModel.settings.pool_size > 0
            ConnectionPool.connection do |connection|
              yield connection
            end
          else
            yield Neo4j::Bolt::Connection.new(Neo4jModel.settings.neo4j_bolt_url, ssl: false)
          end
        end
      end

      def initialize
        initialize(Hash(String, PropertyType).new)
      end

      def initialize(**params)
        @_node.properties["uuid"] = @_uuid

        new_hash = Hash(String, PropertyType).new
        params.each { |k, v| new_hash[k.to_s] = v }
        set_attributes(new_hash)
      end

      def initialize(hash : Hash(String, PropertyType))
        @_node.properties["uuid"] = @_uuid
        set_attributes(hash)
      end

      def initialize(node : Neo4j::Node)
        @_persisted = true
        @_node = node
        @_uuid = @_node.properties["uuid"].as(String)
        set_attributes(from: @_node)
      end
    end # macro included
  end
end
