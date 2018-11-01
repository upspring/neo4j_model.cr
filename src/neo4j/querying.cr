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

        @_executed : Bool = false
        @_objects = Array({{@type.id}}).new
        @_rels = Array(Neo4j::Relationship).new

        # expose query building properties to make debugging easier
        property cypher_query : String?
        property cypher_params = Hash(String, Neo4j::Type).new

        property match
        property wheres = Array(Tuple(String, String, ParamsHash)).new
        property create_merge = ""
        property sets = Array(Tuple(String, ParamsHash)).new
        property order_bys = Array(Tuple((Symbol | String), SortDirection)).new
        property skip = 0
        property limit = 500 # relatively safe default value; adjust appropriately
        property ret # note: destroy uses this to DETACH DELETE instead of RETURN

        # for associations
        property add_proxy : QueryProxy?
        property delete_proxy : QueryProxy?

        def initialize(@match = "MATCH (n:#{{{@type.id}}.label})", @ret = "RETURN n") # all other parameters are added by chaining methods
        end
        
        def initialize(@match, @create_merge, @ret) # all other parameters are added by chaining methods
        end

        def <<(obj : (String | {{@type.id}}))
          if (proxy = @add_proxy)
            target_uuid = obj.is_a?(String) ? obj : obj.uuid

            proxy.reset_query
            proxy.cypher_params["target_uuid"] = target_uuid
            proxy.execute
          else
            raise "add_proxy not set"
          end
        end

        def delete(obj : (String | {{@type.id}}))
          if (proxy = @delete_proxy)
            target_uuid = obj.is_a?(String) ? obj : obj.uuid

            proxy.reset_query
            proxy.cypher_params["target_uuid"] = target_uuid
            proxy.execute
          else
            raise "delete_proxy not set"
          end
        end

        def clone_for_chain
          # clone the query, not the results
          new_query_proxy = self.class.new(@match, @create_merge, @ret)
          \{% for var in [:wheres, :sets, :order_bys, :skip, :limit] %}
            new_query_proxy.\{{var.id}} = @\{{var.id}}
          \{% end %}

          new_query_proxy
        end

        # NamedTuple does not have .each_with_object
        private def sanitize_params_hash(params)
          new_hash = ParamsHash.new
          params.each { |k, v| new_hash[k.to_s] = v }
          new_hash
        end

        def where(str : String, **params)
          @wheres << { str, "", sanitize_params_hash(params) }
          clone_for_chain
        end
        def where(**params)
          @wheres << { "", "", sanitize_params_hash(params) }
          clone_for_chain
        end

        def where_not(str : String, **params)
          @wheres << { str, "NOT", sanitize_params_hash(params) }
          clone_for_chain
        end
        def where_not(**params)
          @wheres << { "", "NOT", sanitize_params_hash(params) }
          clone_for_chain
        end

        def set(**params)
          @sets << { "", sanitize_params_hash(params) }
          clone_for_chain
        end

        def set(params : ParamsHash)
          @sets << { "", sanitize_params_hash(params) }
          clone_for_chain
        end

        def set_label(label : String)
          @sets << { "n:#{label}", ParamsHash.new }
          clone_for_chain
        end

        # TODO: remove_label(label : String)

        def order(prop : Symbol, dir : SortDirection = Neo4j::Model::SortDirection::ASC)
          @order_bys << { prop, dir }
          clone_for_chain
        end

        def skip(@skip)
          clone_for_chain
        end

        def limit(@limit)
          clone_for_chain
        end

        def count
          orig_ret, @ret = @ret, "RETURN COUNT(*)"
          val = execute_count
          @ret = orig_ret

          val
        end

        def reset_query
          @cypher_query = nil
          @cypher_params.try(&.clear)
          clone_for_chain # ?
        end

        def build_cypher_query
          @cypher_query = String.build do |cypher_query|
            cypher_query << @match

            if wheres.any?
              cypher_query << " WHERE "
              wheres.each_with_index do |(str, not, params), index|
                cypher_query << "NOT " if not != ""

                if str == ""
                  cypher_query << params.map { |k, v| v ? "(n.`#{k}` = $#{k}_w#{index})" : "(n.`#{k}` IS NULL)" }.join(" AND ")
                  params.each { |k, v| @cypher_params["#{k}_w#{index}"] = v if v }
                else
                  cypher_query << "#{str}"
                  params.each { |k, v| @cypher_params[k.to_s] = v }
                end
              end
            end

            cypher_query << " #{@create_merge}" unless @create_merge == ""

            if sets.any?
              cypher_query << " SET "
              sets.each_with_index do |(str, params), index|
                cypher_query << ", " if index > 0
                cypher_query << "#{str} " + params.map { |k, v| v ? "n.`#{k}` = $#{k}_s#{index}" : "n.`#{k}` = NULL" }.join(", ")
                params.each { |k, v| @cypher_params["#{k}_s#{index}"] = v if v }
              end
            end

            cypher_query << " #{@ret}" unless @ret == ""

            if @create_merge == "" && @ret !~ /delete/i
              cypher_query << " ORDER BY " + @order_bys.map { |(prop, dir)| "`#{prop}` #{dir.to_s}" }.join(", ") if @order_bys.any?
              cypher_query << " SKIP #{@skip} LIMIT #{@limit}"
            end
          end

          puts "#{Time.utc_now.to_s("%H:%M:%S")} neo4j_model | Constructed Cypher query: #{@cypher_query}"
          puts "#{Time.utc_now.to_s("%H:%M:%S")} neo4j_model |   with params: #{@cypher_params.inspect}"
        end

        def execute
          build_cypher_query

          @_objects = Array({{@type.id}}).new
          @_rels = Array(Neo4j::Relationship).new
          {{@type.id}}.connection.execute(@cypher_query, @cypher_params).each do |result|
            if (node = result[0]?)
              @_objects << {{@type.id}}.new(node.as(Neo4j::Node))
            end
            if (rel = result[1]?)
              @_rels << rel.as(Neo4j::Relationship)
            end
          end

          @_executed = true # FIXME - needs error checking

          self
        end

        def execute_count
          build_cypher_query

          count : Integer = 0

          {{@type.id}}.connection.execute(@cypher_query, @cypher_params).each do |result|
            if (val = result[0]?)
              count = val.as(Integer)
            else
              raise "Error while reading value of COUNT"
            end
          end

          count
        end

        def executed?
          @_executed
        end

        def each
          execute unless executed?

          @_objects.each do |obj|
            yield obj
          end
        end

        def each_with_rel
          execute unless executed?

          return unless @_rels.size == @_objects.size

          @_objects.each_with_index do |obj, index|
            yield obj, @_rels[index]
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

          @_objects
        end

        def [](index)
          execute unless executed?

          @_objects[index]
        end

        def size
          execute unless executed?

          @_objects.size
        end
      end # class QueryProxy

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

      def self.count
        QueryProxy.new.count
      end

      def self.where(str : String, **params)
        QueryProxy.new.where(str, **params)
      end
      def self.where(**params)
        QueryProxy.new.where(**params)
      end

      def self.where_not(str : String, **params)
        QueryProxy.new.where_not(str, **params)
      end
      def self.where_not(**params)
        QueryProxy.new.where_not(**params)
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

      def self.find_or_initialize_by(**params)
        find_by(**params) || new(**params)
      end

      def self.find_or_create_by(**params)
        find_by(**params) || create(**params)
      end

      def self.create(params : Hash)
        QueryProxy.new("CREATE (n:#{label})").set(params).execute.first
      end

      def self.create(**params)
        QueryProxy.new("CREATE (n:#{label})").set(**params).execute.first
      end

      def self.destroy_all
        QueryProxy.new("MATCH (n:#{label})", "DETACH DELETE n").execute
        true # FIXME: check for errors
      end
    end # macro included

    def destroy
      self.class.query_proxy.new("MATCH (n:#{label})", "DETACH DELETE n").where(uuid: uuid).execute
      true # FIXME: check for errors
    end
  end
end
