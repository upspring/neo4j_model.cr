require "neo4j"
require "uuid"

module Neo4j
  module Model
    enum SortDirection
      ASC
      DESC
    end

    alias ParamsHash = Hash((Symbol | String), Neo4j::Type)

    macro included
      # works with a very simplified model of Cypher (MATCH, WHEREs, ORDER BYs, SKIP, LIMIT, RETURN)
      class QueryProxy
        include Enumerable(Array({{@type.id}}))

        getter? executed : Bool = false
        getter objects = Array({{@type.id}}).new
        getter rels = Array(Neo4j::Relationship).new

        property cypher_query : String?
        property match
        property wheres = Array(Tuple(String, ParamsHash)).new
        property sets = Array(Tuple(String, ParamsHash)).new
        property order_bys = Array(Tuple((Symbol | String), SortDirection)).new
        property skip = 0
        property limit = 500 # relatively safe default value; adjust appropriately
        property ret # note: destroy uses this to DETACH DELETE instead of RETURN

        def initialize(@match = "MATCH (n:#{{{@type.id}}.label})", @ret = "RETURN n") # all other parameters are added by chaining methods
        end

        # NamedTuple does not have .each_with_object
        private def sanitize_params_hash(params)
          new_hash = ParamsHash.new
          params.each { |k, v| new_hash[k.to_s] = v }
          new_hash
        end

        def where(str : String, **params)
          @wheres << { str, sanitize_params_hash(params) }
          self
        end

        def where(**params)
          @wheres << { "", sanitize_params_hash(params) }
          self
        end

        def set(**params)
          @sets << { "", sanitize_params_hash(params) }
          self
        end

        def set(params : ParamsHash)
          @sets << { "", sanitize_params_hash(params) }
          self
        end

        def set_label(label : String)
          @sets << { "n:#{label}", ParamsHash.new }
          self
        end

        # TODO: remove_label(label : String)

        def order(prop : Symbol, dir : SortDirection = Neo4j::Model::SortDirection::ASC)
          @order_bys << { prop, dir }
          self
        end

        def skip(@skip)
          self
        end

        def limit(@limit)
          self
        end

        def execute
          cypher_params = Hash(String, Neo4j::Type).new
          @cypher_query = String.build do |cypher_query|
            cypher_query << @match

            if wheres.any?
              cypher_query << " WHERE "
              wheres.each_with_index do |(str, params), index|
                cypher_query << " #{str} " + params.keys.map { |k| "(n.`#{k}` = $#{k}_w#{index})" }.join(" AND ")
                params.each { |k, v| cypher_params["#{k}_w#{index}"] = v }
              end
            end

            if sets.any?
              cypher_query << " SET "
              sets.each_with_index do |(str, params), index|
                cypher_query << ", " if index > 0
                cypher_query << "#{str} " + params.keys.map { |k| "n.`#{k}` = $#{k}_s#{index}" }.join(", ")
                params.each { |k, v| cypher_params["#{k}_s#{index}"] = v }
              end
            end

            cypher_query << " #{@ret}"
            cypher_query << "ORDER BY " + @order_bys.map { |(prop, dir)| "`#{prop}` #{dir.to_s}" }.join(", ") if @order_bys.any?
            # cypher_query << " SKIP #{@skip} LIMIT #{@limit}"
          end

          @objects = [] of {{@type.id}}
          @rels = [] of Neo4j::Relationship
          puts "#{Time.utc_now.to_s("%H:%M:%S")} neo4j_model | executing Cypher query: #{@cypher_query}"
          puts "#{Time.utc_now.to_s("%H:%M:%S")} neo4j_model |   with params: #{cypher_params.inspect}"
          {{@type.id}}.connection.execute(@cypher_query, cypher_params).each do |result|
            if (node = result[0]?)
              @objects << {{@type.id}}.new(node.as(Neo4j::Node))
            end
            if (rel = result[1]?)
              @rels << rel.as(Neo4j::Relationship)
            end
          end

          @executed = true # FIXME - needs error checking

          self
        end

        def each
          execute unless executed?

          @objects.each do |obj|
            yield obj
          end
        end

        def each_with_rel
          execute unless executed?

          return unless @rels.size == @objects.size

          @objects.each_with_index do |obj, index|
            yield obj, @rels[index]
          end
        end

        def first
          to_a.first
        end
        
        def first?
          to_a.first?
        end

        def to_a
          execute unless executed?

          @objects
        end

        def [](index)
          execute unless executed?

          @objects[index]
        end

        def size
          execute unless executed?

          @objects.size
        end
      end

      def self.query_proxy
        QueryProxy
      end

      def self.all
        QueryProxy.new
      end

      def self.first
        QueryProxy.new.limit(1).first
      end

      def self.first?
        QueryProxy.new.limit(1).first?
      end

      def self.where(**params)
        QueryProxy.new.where(**params)
      end

      def self.find!(uuid : String?)
        raise "find! called with nil uuid param" unless uuid

        where(uuid: uuid).first
      end

      def self.find(uuid : String?)
        return nil unless uuid

        where(uuid: uuid).first?
      end

      def self.find_by(**params)
        where(**params).first?
      end

      def self.create(params : Hash)
        QueryProxy.new("CREATE (n)").set(params).set_label(label).execute
      end

      def self.create(**params)
        QueryProxy.new("CREATE (n)").set(**params).set_label(label).execute
      end

      def self.destroy_all
        QueryProxy.new("MATCH (n:#{label})", "DETACH DELETE n").execute
      end
    end # macro included

    def destroy
      self.class.query_proxy.new("MATCH (n:#{label})", "DETACH DELETE n").where(uuid: uuid).execute
    end
  end
end
