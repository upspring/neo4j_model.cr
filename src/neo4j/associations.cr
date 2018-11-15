require "neo4j"

module Neo4j
  module Model
    # equivalent of ActiveNode has_one :out
    macro has_one(klass, *, rel_type, name = "", unique = true)
      {% name = (name == "" ? klass.id.underscore : name.id) %}

      setter {{name}}_id : String?

      class QueryProxy
        # QueryProxy instance method, for chaining
        # FIXME: just adding 's' to pluralize is not always right
        def {{name}}s : {{klass.id}}::QueryProxy
          proxy = {{klass.id}}::QueryProxy.new("MATCH ({{@type.id.underscore}}:#{label})-[r:{{rel_type.id}}]->({{name}}:#{{{klass.id}}.label})",
                                               "RETURN {{name}}, r").query_as(:{{name}})
          self.chain proxy
        end

        # QueryProxy instance method, for normal use (returns object)
        def {{name}} : {{klass.id}}?
          {{name}}s.first_with_rel?
        end
      end

      # FIXME: just adding 's' to pluralize is not always right
      # instance method, to start a chained query
      def {{name}}s
        # create a proxy for all queries related to this association
        proxy = QueryProxy.new.{{name}}s

        # this is the beginning of the chain, should start with a uuid match (provided by #query_proxy)
        context = query_proxy
        proxy = context.chain proxy
      end

      # instance method, for normal use (returns object)
      def {{name}}
        {{name}}s.first_with_rel?
      end

      def {{name}}=(target : {{klass.id}}?)
        if target
          @{{name}}_id = target.uuid
          target
        else
          @{{name}}_id = nil
        end
        target
      end

      def {{name}}_id
        if @{{name}}_id
          @{{name}}_id
        elsif (obj = {{name}})
          @{{name}}_id = obj.id
        end
      end

      def persist_{{name}}_id
        # remove any existing rels of this type
        {{klass.id}}::QueryProxy.new("MATCH (n:#{label} {uuid: '#{uuid}'})-[r:{{rel_type.id}}]->(m)", "DELETE r").execute

        if (target_uuid = {{name}}_id)
          {{klass.id}}::QueryProxy.new("MATCH (n:#{label} {uuid: '#{uuid}'}), (m:#{{{klass.id}}.label} {uuid: '#{target_uuid}'})",
                                       "MERGE (n)-[r:{{rel_type.id}}]->(m)", "RETURN n").execute
        end
      end
    end

    # equivalent of ActiveNode has_many :out
    macro has_many(klass, *, rel_type, name = "", unique = true)
      {% name = (name == "" ? klass.id.underscore + "s" : name.id) %}

      setter {{name}}_ids : Array(String)?

      class QueryProxy
        # QueryProxy instance method, for chaining
        def {{name}} : {{klass.id}}::QueryProxy
          proxy = {{klass.id}}::QueryProxy.new("MATCH ({{@type.id.underscore}}:#{label})-[r:{{rel_type.id}}]->({{name}}:#{{{klass.id}}.label})",
                                               "RETURN {{name}}, r").query_as(:{{name}})
          self.chain proxy
        end
      end

      # instance method, either to start a chained query or to do regular operations (list, add/delete)
      def {{name}}
        proxy = QueryProxy.new.{{name}}

        # while we have the proper context (label & uuid), generate queries to add and remove relationships
        proxy.add_proxy = {{klass.id}}::QueryProxy.new("MATCH (n:#{label} {uuid: '#{uuid}'}), (m:#{{{klass.id}}.label} {uuid: $target_uuid})",
                                                       "MERGE (n)-[r:{{rel_type.id}}]->(m)", "RETURN m, r")
        proxy.delete_proxy = {{klass.id}}::QueryProxy.new("MATCH (n:#{label} {uuid: '#{uuid}'})-[r:{{rel_type.id}}]->(m:#{{{klass.id}}.label} {uuid: $target_uuid})", "DELETE r")

        # this is the beginning of the chain, should start with a uuid match (provided by #query_proxy)
        context = query_proxy
        proxy = context.chain proxy
      end

      def {{name}}_ids
        if (ids = @{{name}}_ids)
          ids
        else
          @{{name}}_ids = {{name}}.to_a.map(&.id).compact
        end
      end

      def persist_{{name}}_ids
        # at this point, @name_ids is the desired state, and
        # the database rels (existing_ids) are not there yet
        existing_ids = {{name}}.to_a.map(&.id).compact
        new_ids = {{name}}_ids - existing_ids
        old_ids = existing_ids - {{name}}_ids

        # add new rels, remove old rels
        new_ids.each { |id| {{name}} << id }
        old_ids.each { |id| {{name}}.delete id }

        true
      end
    end

    # equivalent of ActiveNode has_one :in
    macro belongs_to(klass, *, rel_type, name = "", unique = true)
      {% name = (name == "" ? klass.id.underscore : name.id) %}

      setter {{name}}_id : String?

      class QueryProxy
        # QueryProxy instance method, for chaining
        # FIXME: just adding 's' to pluralize is not always right
        def {{name}}s : {{klass.id}}::QueryProxy
          proxy = {{klass.id}}::QueryProxy.new("MATCH ({{@type.id.underscore}}:#{label})<-[r:{{rel_type.id}}]-({{name}}:#{{{klass.id}}.label})",
                                               "RETURN {{name}}, r").query_as(:{{name}})
          self.chain proxy
        end

        # QueryProxy instance method, for normal use (returns object)
        def {{name}} : {{klass.id}}?
          {{name}}s.first_with_rel?
        end
      end

      # FIXME: just adding 's' to pluralize is not always right
      # instance method, to start a chained query
      def {{name}}s
        # create a proxy for all queries related to this association
        proxy = QueryProxy.new.{{name}}s

        # this is the beginning of the chain, should start with a uuid match (provided by #query_proxy)
        context = query_proxy
        proxy = context.chain proxy
      end

      # instance method, for normal use (returns object)
      def {{name}}
        {{name}}s.first_with_rel?
      end

      def {{name}}=(target : {{klass.id}}?)
        if target
          self.{{name}}_id = target.uuid
          target
        else
          @{{name}}_id = nil
        end
      end

      def {{name}}_id
        if @{{name}}_id
          @{{name}}_id
        elsif (obj = {{name}})
          @{{name}}_id = obj.uuid
        end
      end

      def persist_{{name}}_id
        # remove any existing rels of this type
        {{klass.id}}::QueryProxy.new("MATCH (n:#{label} {uuid: '#{uuid}'})<-[r:{{rel_type.id}}]-(m)", "DELETE r").execute

        if (target_uuid = {{name}}_id)
          {{klass.id}}::QueryProxy.new("MATCH (n:#{label} {uuid: '#{uuid}'}), (m:#{{{klass.id}}.label} {uuid: '#{target_uuid}'})",
                                       "MERGE (n)<-[r:{{rel_type.id}}]-(m)", "RETURN n").execute
        end
      end
    end

    # equivalent of ActiveNode has_many :in
    macro belongs_to_many(klass, *, rel_type, name = "", unique = true)
      {% name = (name == "" ? klass.id.underscore + "s" : name.id) %}

      setter {{name}}_ids : Array(String)?

      class QueryProxy
        # QueryProxy instance method, for chaining
        def {{name}} : {{klass.id}}::QueryProxy
          proxy = {{klass.id}}::QueryProxy.new("MATCH ({{@type.id.underscore}}:#{label})<-[r:{{rel_type.id}}]-({{name}}:#{{{klass.id}}.label})",
                                               "RETURN {{name}}, r").query_as(:{{name}})
          self.chain proxy
        end
      end

      # instance method, either to start a chained query or to do regular operations (list, add/delete)
      def {{name}}
        proxy = QueryProxy.new.{{name}}

        # while we have the proper context (label & uuid), generate queries to add and remove relationships
        proxy.add_proxy = {{klass.id}}::QueryProxy.new("MATCH (n:#{label} {uuid: '#{uuid}'}), (m:#{{{klass.id}}.label} {uuid: $target_uuid})",
                                                       "MERGE (n)<-[r:{{rel_type.id}}]-(m)", "RETURN m, r")
        proxy.delete_proxy = {{klass.id}}::QueryProxy.new("MATCH (n:#{label} {uuid: '#{uuid}'})<-[r:{{rel_type.id}}]-(m:#{{{klass.id}}.label} {uuid: $target_uuid})", "DELETE r")

        # this is the beginning of the chain, should start with a uuid match (provided by #query_proxy)
        context = query_proxy
        proxy = context.chain proxy
      end

      def {{name}}_ids
        if (ids = @{{name}}_ids)
          ids
        else
          @{{name}}_ids = {{name}}.to_a.map(&.id).compact
        end
      end

      def persist_{{name}}_ids
        # at this point, @name_ids is the desired state, and
        # the database rels (existing_ids) are not there yet
        existing_ids = {{name}}.to_a.map(&.id).compact
        new_ids = {{name}}_ids - existing_ids
        old_ids = existing_ids - {{name}}_ids

        # add new rels, remove old rels
        new_ids.each { |id| {{name}} << id }
        old_ids.each { |id| {{name}}.delete id }

        true
      end
    end
  end
end
