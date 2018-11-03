require "neo4j"

module Neo4j
  module Model
    # equivalent of ActiveNode has_one :out
    macro has_one(klass, *, rel_type, name = "", unique = true)
      {% name = (name == "" ? klass.id.underscore : name.id) %}

      class QueryProxy
        # QueryProxy instance method, for chaining
        # FIXME: just adding 's' to pluralize is not always right
        def {{name.id}}s : {{klass.id}}::QueryProxy
          proxy = {{klass.id}}::QueryProxy.new("MATCH ({{@type.id.underscore}}:#{label})-[r:{{rel_type.id}}]->({{klass.id.underscore}}:#{{{klass.id}}.label})",
                                               "RETURN {{klass.id.underscore}}, r")
          self.chain proxy
        end

        # QueryProxy instance method, for normal use (returns object)
        def {{name.id}} : {{klass.id}}?
          {{name.id}}s.first_with_rel?
        end
      end

      # FIXME: just adding 's' to pluralize is not always right
      # instance method, to start a chained query
      def {{name.id}}s
        # create a proxy for all queries related to this association
        proxy = QueryProxy.new.{{name.id}}s

        # this is the beginning of the chain, should start with a uuid match (provided by #query_proxy)
        context = query_proxy
        proxy = context.chain proxy
      end

      def {{name.id}}=(target : {{klass.id}}?)
        if target
          {{name.id}}_id = target.uuid
        else
          {{name.id}}_id = nil
        end
        target
      end

      def {{name.id}}_id
        if (obj = {{name.id}})
          obj.id
        end
      end

      def {{name.id}}_id=(target_uuid : String?)
        # remove any existing rels of this type
        {{klass.id}}::QueryProxy.new("MATCH (n:#{label} {uuid: '#{uuid}'})-[r:{{rel_type.id}}]->(m)", "DELETE r").execute

        return unless target_uuid

        ret = nil
        {{klass.id}}::QueryProxy.new("MATCH (n:#{label} {uuid: '#{uuid}'}), (m:#{{{klass.id}}.label} {uuid: '#{target_uuid}'})",
                                      "MERGE (n)-[r:{{rel_type.id}}]->(m)", "RETURN m, r").each_with_rel do |obj, rel|
          obj._rel = rel
          ret = obj
        end
        ret
      end
    end

    # equivalent of ActiveNode has_many :out
    macro has_many(klass, *, rel_type, name = "", unique = true)
      {% name = (name == "" ? klass.id.underscore + 's' : name.id) %}

      class QueryProxy
        # QueryProxy instance method, for chaining
        def {{name.id}} : {{klass.id}}::QueryProxy
          proxy = {{klass.id}}::QueryProxy.new("MATCH ({{@type.id.underscore}}:#{label})-[r:{{rel_type.id}}]->({{klass.id.underscore}}:#{{{klass.id}}.label})",
                                               "RETURN {{klass.id.underscore}}, r")
          self.chain proxy
        end
      end

      # instance method, either to start a chained query or to do regular operations (list, add/delete)
      def {{name.id}}
        proxy = QueryProxy.new.{{name.id}}

        # while we have the proper context (label & uuid), generate queries to add and remove relationships
        proxy.add_proxy = {{klass.id}}::QueryProxy.new("MATCH (n:#{label} {uuid: '#{uuid}'}), (m:#{{{klass.id}}.label} {uuid: $target_uuid})",
                                                       "MERGE (n)-[r:{{rel_type.id}}]->(m)", "RETURN m, r")
        proxy.delete_proxy = {{klass.id}}::QueryProxy.new("MATCH (n:#{label} {uuid: '#{uuid}'})-[r:{{rel_type.id}}]->(m:#{{{klass.id}}.label} {uuid: $target_uuid})", "DELETE r")

        # this is the beginning of the chain, should start with a uuid match (provided by #query_proxy)
        context = query_proxy
        proxy = context.chain proxy
      end
    end

    # equivalent of ActiveNode has_one :in
    macro belongs_to(klass, *, rel_type, name = "", unique = true)
      {% name = (name == "" ? klass.id.underscore : name.id) %}

      class QueryProxy
        # QueryProxy instance method, for chaining
        # FIXME: just adding 's' to pluralize is not always right
        def {{name.id}}s : {{klass.id}}::QueryProxy
          proxy = {{klass.id}}::QueryProxy.new("MATCH ({{@type.id.underscore}}:#{label})<-[r:{{rel_type.id}}]-({{klass.id.underscore}}:#{{{klass.id}}.label})",
                                               "RETURN {{klass.id.underscore}}, r")
          self.chain proxy
        end

        # QueryProxy instance method, for normal use (returns object)
        def {{name.id}} : {{klass.id}}?
          {{name.id}}s.first_with_rel?
        end
      end

      # FIXME: just adding 's' to pluralize is not always right
      # instance method, to start a chained query
      def {{name.id}}s
        # create a proxy for all queries related to this association
        proxy = QueryProxy.new.{{name.id}}s

        # this is the beginning of the chain, should start with a uuid match (provided by #query_proxy)
        context = query_proxy
        proxy = context.chain proxy
      end

      # instance method, for normal use (returns object)
      def {{name.id}}
        {{name.id}}s.first_with_rel?
      end

      def {{name.id}}=(target : {{klass.id}}?)
        if target
          {{name.id}}_id = target.uuid
        else
          {{name.id}}_id = nil
        end
      end

      def {{name.id}}_id
        if (obj = {{name.id}})
          obj.id
        end
      end

      def {{name.id}}_id=(target_uuid : String?)
        # remove any existing rels of this type
        {{klass.id}}::QueryProxy.new("MATCH (n:#{label} {uuid: '#{uuid}'})<-[r:{{rel_type.id}}]-(m)", "DELETE r").execute

        return unless target_uuid

        ret = nil
        {{klass.id}}::QueryProxy.new("MATCH (n:#{label} {uuid: '#{uuid}'}), (m:#{{{klass.id}}.label} {uuid: '#{target_uuid}'})",
                                     "MERGE (n)<-[r:{{rel_type.id}}]-(m)", "RETURN m, r").each_with_rel do |obj, rel|
          obj._rel = rel
          ret = obj
        end
        ret
      end
    end

    # equivalent of ActiveNode has_many :in
    macro belongs_to_many(klass, *, rel_type, name = "", unique = true)
      {% name = (name == "" ? klass.id.underscore + 's' : name.id) %}

      class QueryProxy
        # QueryProxy instance method, for chaining
        def {{name.id}} : {{klass.id}}::QueryProxy
          proxy = {{klass.id}}::QueryProxy.new("MATCH ({{@type.id.underscore}}:#{label})<-[r:{{rel_type.id}}]-({{klass.id.underscore}}:#{{{klass.id}}.label})",
                                               "RETURN {{klass.id.underscore}}, r")
          self.chain proxy
        end
      end

      # instance method, either to start a chained query or to do regular operations (list, add/delete)
      def {{name.id}}
        proxy = QueryProxy.new.{{name.id}}

        # while we have the proper context (label & uuid), generate queries to add and remove relationships
        proxy.add_proxy = {{klass.id}}::QueryProxy.new("MATCH (n:#{label} {uuid: '#{uuid}'}), (m:#{{{klass.id}}.label} {uuid: $target_uuid})",
                                                       "MERGE (n)-[r:{{rel_type.id}}]->(m)", "RETURN m, r")
        proxy.delete_proxy = {{klass.id}}::QueryProxy.new("MATCH (n:#{label} {uuid: '#{uuid}'})-[r:{{rel_type.id}}]->(m:#{{{klass.id}}.label} {uuid: $target_uuid})", "DELETE r")

        # this is the beginning of the chain, should start with a uuid match (provided by #query_proxy)
        context = query_proxy
        proxy = context.chain proxy
      end
    end
  end
end
