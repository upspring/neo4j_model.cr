require "neo4j"
require "uuid"

module Neo4j
  module Model
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
    end
  end
end
