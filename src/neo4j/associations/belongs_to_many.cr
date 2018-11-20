require "neo4j"

module Neo4j
  module Model
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
