require "neo4j"
require "json"
require "uuid"

# TODO: Write documentation for `Neo4jModel`
module Neo4jModel
  VERSION = "0.1.0"
end

module Neo4j
  class Error
    property property : Symbol
    property message : String

    def initialize(@property, @message)
    end

    def to_s
      "#{@property} #{@message}"
    end
  end

  module Model
    alias Integer = Int8 | Int16 | Int32 | Int64
    alias Changeset = NamedTuple(property: Symbol, old_value: Neo4j::Type?, new_value: Neo4j::Type)

    macro included
      class QueryResult
        include Enumerable(Array({{@type.id}}))

        getter objects : Array({{@type.id}})
        getter rels : Array(Neo4j::Relationship)

        def initialize(@objects, @rels)
        end

        def each
          @objects.each do |obj|
            yield obj
          end
        end

        def each_with_rel
          return unless @rels.size == @objects.size

          @objects.each_with_index do |obj, index|
            yield obj, @rels[index]
          end
        end

        def [](index)
          @objects[index]
        end

        def size
          @objects.size
        end
      end

      # use leading underscore to indicate a property/ivar that should *not* be persisted to neo4j
      property _uuid : String # special because it is persisted on create, but never on update
      property _node : Neo4j::Node
      property _errors = [] of Neo4j::Error
      property _rel : Neo4j::Relationship?

      @@label : String = "{{@type.name}}"
      @@limit = 500 # for safety, lift as needed; FIXME once we have a query proxy system

      def self.connection
        Neo4j::Bolt::Connection.new(ENV["NEO4J_URL"]? || "bolt://neo4j@localhost:7687", ssl: false)
      end

      def self.label
        @@label
      end

      # not sure yet whether we need this version
      # def self.execute(cypher_query : String, *values)
      #   connection.execute(cypher_query, *values).map { |(node)| new(from: node) }
      # end

      def self.execute(cypher_query : String, values = ({} of Symbol => Neo4j::Type))
        hash_with_string_keys = {} of String => Neo4j::Type
        values.each { |key, value| hash_with_string_keys[key.to_s] = value }

        objs = [] of {{@type.id}}
        rels = [] of Neo4j::Relationship
        connection.execute(cypher_query, hash_with_string_keys).each do |result|
          if (node = result[0]?)
            objs << new(from: node)
          end
          if (rel = result[1]?)
            rels << rel.as(Neo4j::Relationship)
          end
        end

        QueryResult.new(objs, rels)
      end

      def self.all
        execute("MATCH (n:#{label}) RETURN n LIMIT #{@@limit}")
      end

      def self.first
        execute("MATCH (n:#{label}) RETURN n LIMIT 1").first
      end

      def self.where(**params)
        execute("MATCH (n:#{label}) " + params.keys.map { |k| "WHERE (n.`#{k}` = $#{k})" }.join(' ') + " RETURN n LIMIT #{@@limit}", params)
      end

      def self.find(uuid : String?)
        return nil unless uuid

        where(uuid: uuid).first
      end

      def self.find_by(**params)
        where(**params).first
      end

      def initialize
        initialize(Hash(String, Neo4j::Type).new)
      end

      def initialize(hash : Hash(String, Neo4j::Type))
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

      # equivalent of ActiveNode has_one :out
      macro has_one(klass, reltype, *, name = "", unique = true)
        \{% name = (name == "" ? klass.id.underscore : name) %}
        def \{{name.id}}
          \{{klass.id}}.execute("MATCH (n:#{label})-[r:\{{reltype.id}}]->(m:#{\{{klass.id}}.label}) RETURN m, r LIMIT 1").each_with_rel do |obj, rel|
            obj._rel = rel ; return obj
          end
        end
      end # macro has_one

      # equivalent of ActiveNode has_many :out
      macro has_many(klass, reltype, *, name = "", unique = true)
        \{% name = (name == "" ? klass.id.underscore + 's' : name) %}
        def \{{name.id}}
          \{{klass.id}}.execute("MATCH (n:#{label})-[r:\{{reltype.id}}]->(m:#{\{{klass.id}}.label}) RETURN m, r LIMIT #{@@limit}")
        end
      end # macro has_many

      # equivalent of ActiveNode has_one :in
      macro belongs_to(klass, reltype, *, name = "", unique = true)
        \{% name = (name == "" ? klass.id.underscore : name) %}
        def \{{name.id}}
        \{{klass.id}}.execute("MATCH (n:#{label})<-[r:\{{reltype.id}}]-(m:#{\{{klass.id}}.label}) RETURN m, r LIMIT 1").each_with_rel do |obj, rel|
            obj._rel = rel ; return obj
          end
        end
      end # macro belongs_to

      # equivalent of ActiveNode has_many :in
      macro belongs_to_many(klass, reltype, *, name = "", unique = true)
        \{% name = (name == "" ? klass.id.underscore + 's' : name) %}
        def \{{name.id}}
          \{{klass.id}}.execute("MATCH (n:#{label})<-[r:\{{reltype.id}}]-(m:#{\{{klass.id}}.label}) RETURN m, r LIMIT #{@@limit}")
        end
      end # macro belongs_to_many
    end # macro included

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

    def persisted?
      @_persisted
    end

    def new_record?
      !@_persisted
    end

    def errors
      @_errors
    end

    def set_attributes(from node : Neo4j::Node)
      {% for var in @type.instance_vars.reject { |v| v.name =~ /^_/ } %}
      if node.properties.has_key?("{{var}}")
        {% if var.type <= Array || (var.type.union? && var.type.union_types.includes?(Array)) %}
          @{{var}} = JSON.parse(node.properties["{{var}}"].as(String)).as_a.map(&.as_s)
        {% elsif var.type <= Hash || (var.type.union? && var.type.union_types.includes?(Hash)) %}
          @{{var}} = JSON.parse(node.properties["{{var}}"].as(String)).as_h.map { |_k, v| v.as_s }
        {% elsif var.type <= Time || (var.type.union? && var.type.union_types.includes?(Time)) %}
          @{{var}} = Time.epoch(node.properties["{{var}}"].as(Int))
        {% else %}
          @{{var}} = node.properties["{{var}}"].as(typeof(@{{var}}))
        {% end %}
      end
      {% end %}
      true
    end

    def set_attributes(hash : Hash(String, T)) forall T
      {% for var in @type.instance_vars.reject { |v| v.name =~ /^_/ } %}
      if hash.has_key?("{{var}}")
        @{{var}} = hash["{{var}}"].as(typeof(@{{var}}))
      end
      {% end %}
    end

    def valid?
      true # we don't support validations yet, so... it's not *wrong*...
    end

    def reload
      return unless  persisted?

      if (db_version = self.class.find(uuid))
        set_attributes(from: db_version.node)
      end
    end

    def update(hash : Hash(String, T)) forall T
      set_attributes(hash)
      save
    end

    def save
      # first, build changeset
      changes = [] of Changeset

      {% for var in @type.instance_vars.reject { |v| v.name =~ /^_/ } %}
        {% if var.type <= Array || (var.type.union? && var.type.union_types.includes?(Array)) %}
        if (old_value = @_node.properties["{{var}}"]?) != (new_value = @{{var}}.to_json)
          changes << { property: :{{var}}, old_value: old_value, new_value: new_value }
        end
        {% elsif var.type <= Hash || (var.type.union? && var.type.union_types.includes?(Hash)) %}
        hash_with_string_keys = {} of String => Type
        @{{var}}.each { |key, value| hash_with_string_keys[key.to_s] = value }
        if (old_value = @_node.properties["{{var}}"]?) != (new_value = hash_with_string_keys.to_json)
          changes << { property: :{{var}}, old_value: old_value, new_value: new_value }
        end
        {% elsif var.type <= Time || (var.type.union? && var.type.union_types.includes?(Time)) %}
        if (local_var = @{{var}}) # remember, this type of guard doesn't work with instance vars, need to snapshot to local var
          if (old_value = @_node.properties["{{var}}"]?) != (new_value = local_var.epoch)
            changes << { property: :{{var}}, old_value: old_value, new_value: new_value }
          elsif (old_value = @_node.properties["{{var}}"]?) != (new_value = nil)
            changes << { property: :{{var}}, old_value: old_value, new_value: new_value }
          end
        end
        {% else %}
        if (old_value = @_node.properties["{{var}}"]?) != (new_value = @{{var}})
          changes << { property: :{{var}}, old_value: old_value, new_value: new_value }
        end
        {% end %}
      {% end %}

      # then persist changeset to database
      if changes.any?
        values = Hash.zip(changes.map(&.[:property]), changes.map(&.[:new_value]))
        values[:uuid] = @_uuid

        if persisted?
          self.class.execute("MATCH (n:#{label}) WHERE (n.uuid = $uuid) SET " + changes.map { |c| "n.`#{c[:property]}` = $#{c[:property]}" }.join(", "), values)
        else
          self.class.execute("CREATE (n) SET n.uuid = $uuid, " + changes.map { |c| "n.`#{c[:property]}` = $#{c[:property]}" }.join(", ") + ", n:#{label}", values)
        end

        true # FIXME
      end

      # finally, update internal node representation
      changes.each { |c| @_node.properties["#{c[:property]}"] = c[:new_value] }
    end
  end
end
