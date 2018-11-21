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
        def {{name}}s(assoc_obj_variable_name = :{{name}}, assoc_rel_variable_name = :r) : {{klass.id}}::QueryProxy
          proxy = {{klass.id}}::QueryProxy.new("MATCH (#{obj_variable_name}:#{label})<-[#{assoc_rel_variable_name}:{{rel_type.id}}]-(#{assoc_obj_variable_name}:#{{{klass.id}}.label})",
                                               "RETURN #{assoc_obj_variable_name}, #{assoc_rel_variable_name}").query_as(assoc_obj_variable_name, assoc_rel_variable_name)
          self.chain proxy
        end

        # QueryProxy instance method, for normal use (returns object)
        def {{name}}(assoc_obj_variable_name = :{{name}}, assoc_rel_variable_name = :r) : {{klass.id}}?
          {{name}}s(assoc_obj_variable_name, assoc_rel_variable_name).first_with_rel?
        end
      end

      # FIXME: just adding 's' to pluralize is not always right
      # instance method, to start a chained query
      def {{name}}s(assoc_obj_variable_name = :{{name}}, assoc_rel_variable_name = :r)
        # create a proxy for all queries related to this association
        proxy = QueryProxy.new.{{name}}s(assoc_obj_variable_name, assoc_rel_variable_name)

        # this is the beginning of the chain, should start with a uuid match (provided by #query_proxy)
        context = query_proxy
        proxy = context.chain proxy
      end

      # instance method, for normal use (returns object)
      def {{name}}(assoc_obj_variable_name = :{{name}}, assoc_rel_variable_name = :r)
        {{name}}s(assoc_obj_variable_name, assoc_rel_variable_name).first_with_rel?
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
