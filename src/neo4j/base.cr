require "neo4j"
require "uuid"

module Neo4j
  module Model
    def uuid
      @_uuid
    end

    def rel
      @_rel
    end

    # id works differently from uuid because sometimes presence of id is used like #persisted?
    # but in our case, for various reasons, we assign a uuid even before the node is created
    def id
      persisted? ? @_uuid : nil
    end

    def label
      self.class.label
    end

    macro included
      def_equals(@_uuid)

      # use leading underscore to indicate a property/ivar that should *not* be persisted to neo4j
      property _uuid : String = UUID.random.to_s # special because it is persisted on create, but never on update
      property _node : Neo4j::Node # snapshot of db node
      property _rel : Neo4j::Relationship?

      # override if you want to use a different label
      class_getter label : String = "{{@type.name}}"

      def self.connection
        Neo4j::Bolt::Connection.new(ENV["NEO4J_URL"]? || "bolt://neo4j@localhost:7687", ssl: false)
      end

      def initialize
        initialize(Hash(String, PropertyType).new)
      end

      def initialize(**params)
        @_persisted = false
        @_node = Neo4j::Node.new(0, Array(String).new, Hash(String, Neo4j::Type).new)
        @_node.properties["uuid"] = @_uuid

        new_hash = Hash(String, PropertyType).new
        params.each { |k, v| new_hash[k.to_s] = v }
        set_attributes(new_hash)
      end

      def initialize(hash : Hash(String, PropertyType))
        @_persisted = false
        @_node = Neo4j::Node.new(0, Array(String).new, Hash(String, Neo4j::Type).new)
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
