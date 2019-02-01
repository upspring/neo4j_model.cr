module Neo4j
  # works with a very simplified model of Cypher (MATCH, WHEREs, ORDER BYs, SKIP, LIMIT, RETURN)
  class QueryProxy
    alias ParamsHash = Hash(Symbol | String, Neo4j::Type)
    alias CypherParamsHash = Hash(String, Neo4j::Type)
    alias Where = Tuple(String, String, ParamsHash)
    alias ExpandedWhere = Tuple(String, CypherParamsHash)
    enum SortDirection
      ASC
      DESC
    end

    @_executed : Bool = false

    # expose query building properties to make debugging easier
    getter cypher_query : String?
    getter cypher_params = CypherParamsHash.new
    getter raw_result : Neo4j::Result?
    getter return_values = Array(CypherParamsHash).new

    property obj_variable_name : String = "n"
    property rel_variable_name : String = "r"

    property match = ""
    property wheres = Array(ExpandedWhere).new
    property create_merge = ""
    property sets = Array(Tuple(String, ParamsHash)).new
    property removes = Array(String).new
    property order_bys = Array(Tuple((Symbol | String), SortDirection)).new
    property skip = 0
    property limit = 500 # relatively safe default value; adjust appropriately
    property ret = ""    # note: destroy uses this to DETACH DELETE instead of RETURN
    property ret_distinct : Bool = false

    # for associations
    property add_proxy : QueryProxy?
    property delete_proxy : QueryProxy?

    # chaining two proxies together will join the two match clauses and wheres (everything else will use the last value)
    def chain(proxy : QueryProxy)
      proxy.match = match.gsub(/\[(\w+\:)(.*?)\]/, "[\\2]") + ", " + proxy.match.gsub(/^MATCH /, "")
      proxy.wheres += wheres
      proxy
    end

    # TODO: want to expose #query_as as part of public api, but would first need to do
    #       some find/replace magic on existing match/create_merge/wheres/ret
    # NOTE: ActiveNode called this .as, but crystal doesn't allow that name
    def query_as(obj_var : (Symbol | String)) : QueryProxy
      @obj_variable_name = obj_var.to_s
      self
    end

    def query_as(obj_var : (Symbol | String), rel_var : (Symbol | String)) : QueryProxy
      @rel_variable_name = rel_var.to_s
      query_as(obj_var)
    end

    # clone the query, not the results
    def clone_for_chain : QueryProxy
      new_query_proxy = self.class.new(@match, @create_merge, @ret)
      {% for var in [:label, :obj_variable_name, :rel_variable_name, :wheres, :sets, :removes, :order_bys, :skip, :limit, :ret_distinct] %}
        new_query_proxy.{{var.id}} = @{{var.id}}.dup
      {% end %}

      new_query_proxy
    end

    # NamedTuple does not have .each_with_object
    private def params_hash_from_named_tuple(params) : ParamsHash
      new_hash = ParamsHash.new
      params.each do |k, v|
        if v.is_a?(Array) # not entirely sure why this is needed (but it is)
          new_hash[k] = v.map(&.as(Neo4j::Type))
        else
          new_hash[k] = v
        end
      end
      new_hash
    end

    # this will be overridden in subclass
    def expand_where(where : Where) : ExpandedWhere
      raise "must redefine expand_where in subclass"
    end

    def where(str : String, **params) : QueryProxy
      @wheres << expand_where({str, "", params_hash_from_named_tuple(params)})
      clone_for_chain
    end

    def where(**params) : QueryProxy
      @wheres << expand_where({"", "", params_hash_from_named_tuple(params)})
      clone_for_chain
    end

    def where_not(str : String, **params) : QueryProxy
      @wheres << expand_where({str, "NOT", params_hash_from_named_tuple(params)})
      clone_for_chain
    end

    def where_not(**params) : QueryProxy
      @wheres << expand_where({"", "NOT", params_hash_from_named_tuple(params)})
      clone_for_chain
    end

    def set(**params) : QueryProxy
      @sets << {"", params_hash_from_named_tuple(params)}
      clone_for_chain
    end

    def set(params) : QueryProxy
      @sets << {"", params_hash_from_named_tuple(params)}
      clone_for_chain
    end

    # this form is mainly for internal use, but use it if you need it
    def order(prop : Symbol, dir : SortDirection = Neo4j::QueryProxy::SortDirection::ASC) : QueryProxy
      @order_bys << expand_order_by(prop, dir)
      clone_for_chain
    end

    # ex: .order(:name, :created_by)
    def order(*params) : QueryProxy
      params.each do |prop|
        @order_bys << expand_order_by(prop, SortDirection::ASC)
      end
      clone_for_chain
    end

    # ex: .order(name: :ASC, created_by: :desc)
    def order(**params) : QueryProxy
      params.each do |prop, dir|
        case dir.to_s.downcase
        when "desc"
          @order_bys << expand_order_by(prop, SortDirection::DESC)
        else
          @order_bys << expand_order_by(prop, SortDirection::ASC)
        end
      end
      clone_for_chain
    end

    def unorder : QueryProxy
      @order_bys.clear
      clone_for_chain
    end

    def reorder(**params) : QueryProxy
      @order_bys.clear
      order(**params)
    end

    # shown here for documentation purposes, but actual definition is in macro
    # included (type-specific subclass) due to conflict with Enumerable#skip
    def skip(@skip) : QueryProxy
      clone_for_chain
    end

    def limit(@limit) : QueryProxy
      clone_for_chain
    end

    def distinct : QueryProxy
      @ret_distinct = true
      clone_for_chain
    end

    def reset_query
      @cypher_query = nil
      @cypher_params.try(&.clear)
      clone_for_chain # ?
    end

    def executed? : Bool
      @_executed
    end
  end

  module Model
    macro included
      # reopen original QueryProxy to add a return method for this type
      class ::Neo4j::QueryProxy
        def return(*, {{@type.id.underscore}}) # argument must not have a default value
          proxy = chain {{@type.id}}::QueryProxy.new
          proxy.first?
        end
      end

      # create custom QueryProxy subclass
      class QueryProxy < Neo4j::QueryProxy
        include Enumerable({{@type.id}})

        property label : String
        property uuid : String?

        @_objects = Array({{@type.id}}).new
        @_rels = Array(Relationship).new

        def initialize(@match = "MATCH ({{@type.id.underscore}}:#{{{@type.id}}.label})",
                       @ret = "RETURN {{@type.id.underscore}}") # all other parameters are added by chaining methods
          @label = {{@type.id}}.label
          @obj_variable_name = "{{@type.id.underscore}}"
        end

        def initialize(@match,
                       @create_merge,
                       @ret) # all other parameters are added by chaining methods
          @label = {{@type.id}}.label
          @obj_variable_name = "{{@type.id.underscore}}"
        end

        def <<(obj : (String | {{@type.id}})) : QueryProxy
          if (proxy = @add_proxy.as({{@type.id}}::QueryProxy))
            target_uuid = obj.is_a?(String) ? obj : obj.uuid

            proxy.reset_query
            proxy.cypher_params["target_uuid"] = target_uuid
            proxy.execute
          else
            raise "add_proxy not set"
          end

          self
        end

        def delete(obj : (String | {{@type.id}})) : QueryProxy
          if (proxy = @delete_proxy.as({{@type.id}}::QueryProxy))
            target_uuid = obj.is_a?(String) ? obj : obj.uuid

            proxy.reset_query
            proxy.cypher_params["target_uuid"] = target_uuid
            proxy.execute
          else
            raise "delete_proxy not set"
          end

          self
        end

        # somewhat confusingly named since we also have a property called label, but not sure how we could do better
        def set_label(label : Symbol | String) : QueryProxy
          @sets << { "#{obj_variable_name}:#{label.to_s}", ParamsHash.new }
          clone_for_chain
        end

        def remove_label(label : Symbol | String) : QueryProxy
          @removes << "#{obj_variable_name}:#{label.to_s}"
          clone_for_chain
        end

        def expand_where(where : Where) : ExpandedWhere
          str, not, params = where
          index = wheres.size + 1

          new_params = CypherParamsHash.new
          expanded_str = String.build do |cypher_query|
            cypher_query << "NOT " if not != ""
            cypher_query << "("

            if str == ""
              cypher_query << params.map { |k, v|
                # id instead of uuid is a common source of frustration
                if k.to_s == "id"
                  Neo4jModel.settings.logger.debug "WARNING: `id` used in where clause. Did you mean `uuid`?"
                end
                if v
                  if v.is_a?(Array)
                    new_params["#{k}_w#{index}"] = v
                    "(#{obj_variable_name}.`#{k}` IN $`#{k}_w#{index}`)"
                  else
                    new_params["#{k}_w#{index}"] = v
                    "(#{obj_variable_name}.`#{k}` = $`#{k}_w#{index}`)"
                  end
                else
                  "(#{obj_variable_name}.`#{k}` IS NULL)"
                end
              }.join(" AND ")
            else
              cypher_query << "#{str}"
              params.each { |k, v| new_params[k.to_s] = v }
            end
            cypher_query << ")"
          end

          { expanded_str, new_params }
        end

        def expand_order_by(prop : Symbol, dir : SortDirection) : Tuple(String, SortDirection)
          { "#{obj_variable_name}.`#{prop}`", dir }
        end

        def build_cypher_query(var_name = obj_variable_name) : String
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

                # method 1: params
                cypher_query << "#{str} " + params.map { |k, v| v.nil? ? "#{var_name}.`#{k}` = NULL" : "#{var_name}.`#{k}` = $`#{k}_s#{index}`" }.join(", ")
                params.each { |k, v| @cypher_params["#{k}_s#{index}"] = v unless v.nil? }

                # method 2: (carefully!) inlining the values
                # cypher_query << "#{str} " + params.map do |k, v|
                #   case v
                #   when Nil then "#{var_name}.`#{k}` = NULL"
                #   when Bool then "#{var_name}.`#{k}` = #{v.to_json}"
                #   when String then "#{var_name}.`#{k}` = #{v.to_json}"
                #   when Int then "#{var_name}.`#{k}` = #{v.to_json}"
                #   when Float then "#{var_name}.`#{k}` = #{v.to_json}"
                #   else
                #     raise "Unexpected parameter type: #{v.class.name}"
                #   end
                # end.join(", ")
              end
            end

            if removes.any?
              cypher_query << " REMOVE "
              removes.each_with_index do |str, index|
                cypher_query << ", " if index > 0
                cypher_query << "#{str} "
              end
            end

            if @ret != ""
              if @ret_distinct
                # DISTINCT doesn't do what we typically want when there are multiple return values
                # cypher_query << " #{@ret.gsub(obj_variable_name, "DISTINCT #{obj_variable_name}")}"
                cypher_query << " #{@ret.gsub(/,.*?$/, "").gsub(obj_variable_name, "DISTINCT #{obj_variable_name}")}"
              else
                cypher_query << " #{@ret}"
              end
            end

            if @create_merge == "" && @ret !~ /delete/i && @ret !~ /count/i
              cypher_query << " ORDER BY " + @order_bys.map { |(prop, dir)| "#{prop} #{dir.to_s}" }.join(", ") if @order_bys.any?
              cypher_query << " SKIP #{@skip}" if @skip.to_i > 0
              cypher_query << " LIMIT #{@limit}" if @limit.to_i > 0 && @match =~ /MATCH/i
            end
          end

          Neo4jModel.settings.logger.debug "Constructed Cypher query: #{@cypher_query}"
          Neo4jModel.settings.logger.debug "  with params: #{@cypher_params.inspect}"

          @cypher_query.not_nil!
        end

        def execute(skip_build = false) : QueryProxy
          build_cypher_query unless skip_build

          {{@type.id}}.with_connection do |conn|
            elapsed_ms = Time.measure { @raw_result = conn.execute(@cypher_query, @cypher_params) }.milliseconds
            Neo4jModel.settings.logger.debug "Executed query (#{elapsed_ms}ms): #{raw_result.not_nil!.type.inspect}"
          rescue ex : Neo4j::QueryException
             # this shouldn't happen anymore, but... leaving it here just in case
            conn.reset
            raise ex
          end

          if (result = raw_result)
            @_objects = Array({{@type.id}}).new
            @_rels = Array(Relationship).new
            @return_values.clear
            fields = Array(String).new

            if (type = result.type.as?(Neo4j::Success))
              fields = type.fields
            end

            result.each do |data|
              if (fields == [obj_variable_name.to_s, rel_variable_name.to_s]) || # the most common case
                 (fields == [obj_variable_name.to_s])                            # the next most common case
                if (node = data[0]?.try &.as?(Neo4j::Node))
                  obj = {{@type.id}}.new(node)
                  @_objects << obj
                  if (rel = data[1]?.try &.as?(Neo4j::Relationship))
                    @_rels << Relationship.new(rel, clone_for_chain.where(uuid: obj.uuid))
                  end
                end
              else # something a little bit more complex... user will sort it out :-D
                @return_values << Hash.zip(fields, data)
              end
            end

            @_executed = true # FIXME - needs error checking
          end

          self
        end

        # typically paired with #limit for pagination
        def skip(@skip)
          clone_for_chain
        end

        def count
          orig_ret, @ret = @ret, "RETURN COUNT(#{obj_variable_name})"
          n : Integer = 0

          build_cypher_query

          {{@type.id}}.with_connection do |conn|
            conn.execute(@cypher_query, @cypher_params).each do |result|
              if (val = result[0]?)
                n = val.as(Integer)
              else
                raise "Error while reading value of COUNT"
              end
            end
          end

          @ret = orig_ret

          n
        end

        def pluck(*props : Symbol | String)
          props_with_var = props.map { |p| "#{obj_variable_name}.`#{p}`" }.join(", ")
          orig_ret, @ret = @ret, "RETURN #{props_with_var}"

          flat_array = Array(Neo4j::Type).new
          hash_array = Array(Hash(Symbol | String, Neo4j::Type)).new

          build_cypher_query
          @ret = orig_ret

          return flat_array if props.size == 0

          {{@type.id}}.with_connection do |conn|
            conn.execute(@cypher_query, @cypher_params).each do |result|
              if props.size == 1
                flat_array << result[0] if result[0]?
              else
                hash = Hash(Symbol | String, Neo4j::Type).new
                result.each_with_index { |val, index| hash[props[index]] = val }
                hash_array << hash
              end
            end
          end

          props.size == 1 ? flat_array : hash_array
        end

        def delete_all
          @ret = "DETACH DELETE #{obj_variable_name}"
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

        def find!(uuid : String?)
          raise "find! called with nil uuid param" unless uuid

          where(uuid: uuid).first
        end

        def find(uuid : String?)
          return nil unless uuid

          where(uuid: uuid).first?
        end

        def find_by(**params)
          where(**params).first?
        end

        def find_by!(**params)
          where(**params).first
        end

        def find_or_initialize_by(**params)
          find_by(**params) || new(**params)
        end

        def find_or_create_by(**params)
          find_by(**params) || create(**params)
        end

        def new(params : Hash)
          {{@type.id}}.new(params)
        end

        def new(**params)
          {{@type.id}}.new(**params)
        end

        def create(params : Hash)
          obj = new(params)
          obj.save
          obj
        end

        def create(**params)
          obj = new(**params)
          obj.save
          obj
        end

        def first : {{@type.id}}
          (executed? ? to_a : limit(1).to_a).first
        end

        def first? : {{@type.id}}?
          (executed? ? to_a : limit(1).to_a).first?
        end

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

        def first_with_rel : {{@type.id}}
          if (val = first_with_rel?)
            val
          else
            raise IndexError.new
          end
        end

        def size
          execute unless executed?

          @_objects.size
        end

        def empty?
          size == 0
        end
      end # QueryProxy subclass

      def self.query_proxy
        QueryProxy
      end

      def self.new_create_proxy
        QueryProxy.new("CREATE ({{@type.id.underscore}}:#{label})").query_as(:{{@type.id.underscore}})
      end

      # query proxy that returns this instance (used as a base for association queries)
      @_query_proxy : QueryProxy?
      def query_proxy : QueryProxy
        if (proxy = @_query_proxy)
          return proxy
        end
        proxy = QueryProxy.new("MATCH ({{@type.id.underscore}}:#{label})", "RETURN {{@type.id.underscore}}").query_as(:{{@type.id.underscore}})
        proxy.where(uuid: uuid)
        proxy.uuid = uuid
        @_query_proxy = proxy
      end

      def self.all
        QueryProxy.new
      end

      def self.first
        QueryProxy.new.first
      end

      def self.first?
        QueryProxy.new.first?
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

      def self.order(*params)
        QueryProxy.new.order(*params)
      end

      def self.order(**params)
        QueryProxy.new.order(**params)
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

      def self.find_by!(**params)
        where(**params).first
      end

      def self.find_or_initialize_by(**params)
        find_by(**params) || new(**params)
      end

      def self.find_or_create_by(**params)
        find_by(**params) || create(**params)
      end

      def self.create(params : Hash)
        obj = new(params)
        obj.save
        obj
      end

      def self.create(**params)
        obj = new(**params)
        obj.save
        obj
      end

      def self.delete_all
        QueryProxy.new.delete_all
      end

      def self.clear
        delete_all
      end


      # FIXME: this version should run callbacks
      def self.destroy_all
        QueryProxy.new.destroy_all
      end

      def destroy
        self.class.query_proxy.new("MATCH (n:#{label} {uuid: '#{uuid}'})", "DETACH DELETE n").execute
        true # FIXME: check for errors
      end
    end # macro included
  end
end
