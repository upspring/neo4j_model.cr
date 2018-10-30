require "neo4j"

module Neo4j
  module Model
    def id
      @_uuid
    end
    def uuid
      @_uuid
    end
    def rel
      @_rel
    end

    def label
      self.class.label
    end

    macro included
      # use leading underscore to indicate a property/ivar that should *not* be persisted to neo4j
      property _uuid : String # special because it is persisted on create, but never on update
      property _node : Neo4j::Node
      property _rel : Neo4j::Relationship?

      @@label : String = "{{@type.name}}"
      @@limit = 500 # for safety, lift as needed; FIXME once we have a query proxy system

      def self.connection
        Neo4j::Bolt::Connection.new(ENV["NEO4J_URL"]? || "bolt://neo4j@localhost:7687", ssl: false)
      end

      def self.label
        @@label
      end

      def initialize
        initialize(Hash(String, PropertyType).new)
      end

      def initialize(hash : Hash(String, PropertyType))
        @_persisted = false
        @_uuid = UUID.random.to_s
        @_node = Neo4j::Node.new(0, ([] of String), Hash{"uuid" => @_uuid.as(Neo4j::Type)})
        @_node.properties["uuid"] = @_uuid
        set_attributes(hash)
      end

      def initialize(from node : Neo4j::Node)
        @_persisted = true
        @_node = node
        @_uuid = node.properties["uuid"].as(String)
        set_attributes(from: node)
      end
    end # macro included
  end
end
