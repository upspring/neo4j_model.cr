require "neo4j"

module Neo4j
  module Model
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
  end
end
