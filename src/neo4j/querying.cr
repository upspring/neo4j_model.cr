require "neo4j"

module Neo4j
  # works with a very simplified model of Cypher (MATCH, WHEREs, ORDER BYs, SKIP, LIMIT, RETURN)
  class QueryProxy
    alias ParamsHash = Hash((Symbol | String), Neo4j::Type)
    alias Where = Tuple(String, String, ParamsHash)
    alias ExpandedWhere = Tuple(String, Hash(String, Neo4j::Type))
    enum SortDirection
      ASC
      DESC
    end

    @_executed : Bool = false

    # expose query building properties to make debugging easier
    property cypher_query : String?
    property cypher_params = Hash(String, Neo4j::Type).new

    property match = ""
    property wheres = Array(ExpandedWhere).new
    property create_merge = ""
    property sets = Array(Tuple(String, ParamsHash)).new
    property order_bys = Array(Tuple((Symbol | String), SortDirection)).new
    property skip = 0
    property limit = 500 # relatively safe default value; adjust appropriately
    property ret = "" # note: destroy uses this to DETACH DELETE instead of RETURN

    # for associations
    property add_proxy : QueryProxy?
    property delete_proxy : QueryProxy?

    # chaining two proxies together will join the two match clauses and wheres (everything else will use the last value)
    def chain(proxy : QueryProxy)
      proxy.match = match.gsub(/\[(\w+\:)(.*?)\]/, "[\\2]") + ", " + proxy.match.gsub(/^MATCH /, "")
      proxy.wheres += wheres
      proxy
    end

    def clone_for_chain
      # clone the query, not the results
      new_query_proxy = self.class.new(@match, @create_merge, @ret)
      {% for var in [:wheres, :sets, :order_bys, :skip, :limit] %}
        new_query_proxy.{{var.id}} = @{{var.id}}
      {% end %}

      new_query_proxy
    end

    # NamedTuple does not have .each_with_object
    private def params_hash_from_named_tuple(params)
      new_hash = ParamsHash.new
      params.each { |k, v| new_hash[k] = v }
      new_hash
    end

    # this will be overridden in subclass
    def expand_where(where : Where) : ExpandedWhere
      raise "must redefine expand_where in subclass"
    end

    def where(str : String, **params)
      @wheres << expand_where({ str, "", params_hash_from_named_tuple(params) })
      clone_for_chain
    end
    def where(**params)
      @wheres << expand_where({ "", "", params_hash_from_named_tuple(params) })
      clone_for_chain
    end

    def where_not(str : String, **params)
      @wheres << expand_where({ str, "NOT", params_hash_from_named_tuple(params) })
      clone_for_chain
    end
    def where_not(**params)
      @wheres << expand_where({ "", "NOT", params_hash_from_named_tuple(params) })
      clone_for_chain
    end

    def set(**params)
      @sets << { "", params_hash_from_named_tuple(params) }
      clone_for_chain
    end

    def set(params : ParamsHash)
      @sets << { "", params_hash_from_named_tuple(params) }
      clone_for_chain
    end

    # this form is mainly for internal use (below), but use it if you need it
    def order(prop : Symbol, dir : SortDirection = Neo4j::Model::SortDirection::ASC)
      @order_bys << { prop, dir }
      clone_for_chain
    end

    # ex: .order(name: :ASC, created_by: :desc)
    def order(**params)
      params.each do |prop, dir|
        case dir.to_s.downcase
        when "desc"
          order(prop, SortDirection::DESC)
        else
          order(prop, SortDirection::ASC)
        end
      end
    end

    def skip(@skip)
      clone_for_chain
    end

    def limit(@limit)
      clone_for_chain
    end

    def reset_query
      @cypher_query = nil
      @cypher_params.try(&.clear)
      clone_for_chain # ?
    end

    def executed?
      @_executed
    end
  end

  module Model
    macro included
      # reopen original QueryProxy to add a return method for this type
      class ::Neo4j::QueryProxy
        def return(*, {{@type.id.underscore}}) # argument must not have a default value
          proxy = chain {{@type.id}}::QueryProxy.new

          # FIXME? maybe later... for now let's ignore the value passed
          # proxy.ret = "RETURN #{{{@type.id.underscore}}}"

          proxy.first?
        end
      end

      # create custom QueryProxy subclass
      class QueryProxy < Neo4j::QueryProxy
        include Enumerable(Array({{@type.id}}))

        property label : String
        property uuid : String?

        @_objects = Array({{@type.id}}).new
        @_rels = Array(Neo4j::Relationship).new

        def initialize(@match = "MATCH ({{@type.id.underscore}}:#{{{@type.id}}.label})", @ret = "RETURN {{@type.id.underscore}}") # all other parameters are added by chaining methods
          @label = {{@type.id}}.label
        end

        def initialize(@match, @create_merge, @ret) # all other parameters are added by chaining methods
          @label = {{@type.id}}.label
        end

        def <<(obj : (String | {{@type.id}}))
          if (proxy = @add_proxy.as({{@type.id}}::QueryProxy))
            target_uuid = obj.is_a?(String) ? obj : obj.uuid

            proxy.reset_query
            proxy.cypher_params["target_uuid"] = target_uuid
            proxy.execute
          else
            raise "add_proxy not set"
          end
        end

        def delete(obj : (String | {{@type.id}}))
          if (proxy = @delete_proxy.as({{@type.id}}::QueryProxy))
            target_uuid = obj.is_a?(String) ? obj : obj.uuid

            proxy.reset_query
            proxy.cypher_params["target_uuid"] = target_uuid
            proxy.execute
          else
            raise "delete_proxy not set"
          end
        end

        # FIXME: somewhat confusingly named since we also have a property called label
        def set_label(label : String)
          @sets << { "n:#{label}", ParamsHash.new }
          clone_for_chain
        end

        # TODO: def remove_label(label : String)

        def expand_where(where : Where) : ExpandedWhere
          str, not, params = where
          index = wheres.size + 1

          new_params = Hash(String, Neo4j::Type).new
          expanded_str = String.build do |cypher_query|
            cypher_query << "NOT " if not != ""
            cypher_query << "("

            if str == ""
              cypher_query << params.map { |k, v|
                if v
                  new_params["#{k}_w#{index}"] = v
                  "({{@type.id.underscore}}.`#{k}` = $#{k}_w#{index})"
                else
                  "({{@type.id.underscore}}.`#{k}` IS NULL)"
                end
              }.join(" AND ")
            else
              cypher_query << "#{str}"
              params.each { |k, v| new_params[k.to_s] = v }
            end
            cypher_query << ")"
          end
          puts "Expanded where: #{expanded_str}"

          { expanded_str, new_params }
        end
    
        def build_cypher_query
          @cypher_query = String.build do |cypher_query|
            cypher_query << @match
    
            if wheres.any?
              cypher_query << " WHERE "
              cypher_query << wheres.map { |(str, params)|
                @cypher_params.merge!(params)
                str
              }.join(" AND ")
            end

            cypher_query << " #{@create_merge}" unless @create_merge == ""
    
            if sets.any?
              cypher_query << " SET "
              sets.each_with_index do |(str, params), index|
                cypher_query << ", " if index > 0
                cypher_query << "#{str} " + params.map { |k, v| v ? "{{@type.id.underscore}}.`#{k}` = $#{k}_s#{index}" : "{{@type.id.underscore}}.`#{k}` = NULL" }.join(", ")
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
              obj = {{@type.id}}.new(node.as(Neo4j::Node))
              @_objects << obj
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

        def count
          orig_ret, @ret = @ret, "RETURN COUNT(*)"
          val = execute_count
          @ret = orig_ret

          val
        end

        def delete_all
          @ret = "DETACH DELETE {{@type.id.underscore}}"
          execute
          true # FIXME: check for errors
        end

        # FIXME: this version should run callbacks
        def destroy_all
          delete_all
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

        def first : {{@type.id}}
          (executed? ? to_a : limit(1).to_a).first
        end

        def first? : {{@type.id}}?
          (executed? ? to_a : limit(1).to_a).first?
        end

        # TODO: def first_with_rel : {{@type.id}}

        def first_with_rel? : {{@type.id}}?
          val = nil

          (executed? ? self : limit(1)).each_with_rel do |obj, rel|
            obj._rel = rel ; obj
            val = obj
          end

          val
        end

        def to_a : Array({{@type.id}})
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
      end # QueryProxy subclass

      def self.query_proxy
        QueryProxy
      end

      # query proxy that returns this instance (used as a base for association queries)
      def query_proxy : QueryProxy
        @_query_proxy ||= QueryProxy.new("MATCH ({{@type.id.underscore}}:#{label} {uuid: '#{uuid}'})", "RETURN {{@type.id.underscore}}")
        proxy = @_query_proxy.not_nil! # FIXME :-(
        proxy.uuid = uuid
        proxy
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
        QueryProxy.new("CREATE ({{@type.id.underscore}}:#{label})").set(params).execute.first
      end

      def self.create(**params)
        QueryProxy.new("CREATE ({{@type.id.underscore}}:#{label})").set(**params).execute.first
      end

      def self.delete_all
        QueryProxy.new.delete_all
      end
        

      # FIXME: this version should run callbacks
      def self.destroy_all
        QueryProxy.new.destroy_all
      end

      def destroy
        self.class.query_proxy.new("MATCH ({{@type.id.underscore}}:#{label})", "DETACH DELETE n").where(uuid: uuid).execute
        true # FIXME: check for errors
      end
    end # macro included
  end
end
