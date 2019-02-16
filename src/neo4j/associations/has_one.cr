require "neo4j"

module Neo4j
  module Model
    # equivalent of ActiveNode has_one :out
    macro has_one(klass, *, rel_type, name = "", plural = "", unique = true)
      {%
        name = (name == "" ? klass.id.underscore : name.id)
        plural = if plural == ""
                   # can handle a few very extremely simple cases here
                   (name + "s").gsub(/sss$/, "sses").gsub(/mans$/, "men").gsub(/childs$/, "children")
                 else
                   plural.id
                 end
      %}

      class QueryProxy
        # QueryProxy instance method, for chaining
        def {{plural}}(assoc_obj_variable_name = :{{name}}, assoc_rel_variable_name = :r) : {{klass.id}}::QueryProxy
          proxy = {{klass.id}}::QueryProxy.new("MATCH (#{obj_variable_name}:#{label})-[#{assoc_rel_variable_name}:{{rel_type.id}}]->(#{assoc_obj_variable_name}:#{{{klass.id}}.label})",
                                               "RETURN #{assoc_obj_variable_name}, #{assoc_rel_variable_name}").query_as(assoc_obj_variable_name, assoc_rel_variable_name)
          self.chain proxy
        end

        # QueryProxy instance method, for normal use (returns object)
        def {{name}}(assoc_obj_variable_name = :{{name}}, assoc_rel_variable_name = :r) : {{klass.id}}?
          {{plural}}(assoc_obj_variable_name, assoc_rel_variable_name).first_with_rel?
        end
      end

      # instance method, to start a chained query
      def {{plural}}(assoc_obj_variable_name = :{{name}}, assoc_rel_variable_name = :r) : {{klass.id}}::QueryProxy
        # create a proxy for all queries related to this association
        proxy = QueryProxy.new.{{plural}}(assoc_obj_variable_name, assoc_rel_variable_name)

        # this is the beginning of the chain, should start with a uuid match (provided by #query_proxy)
        context = query_proxy
        proxy = context.chain proxy
      end

      # instance method, for normal use (returns object)
      def {{name}}(assoc_obj_variable_name = :{{name}}, assoc_rel_variable_name = :r) : {{klass.id}}?
        return nil if @_{{name}}_delete_on_save
        if (obj = {{plural}}(assoc_obj_variable_name, assoc_rel_variable_name).first_with_rel?)
          _node.properties["{{name}}_id"] = obj.uuid
          obj
        end
      end

      def {{name}}=(target : {{klass.id}}?) : {{klass.id}}?
        if target
          self.{{name}}_id = target.uuid
          target
        else
          @{{name}}_id = nil
        end
      end

      def {{name}}_id : String?
        if @{{name}}_id
          @{{name}}_id
        elsif (obj = {{name}})
          @{{name}}_id = obj.id
        end
      end

      def {{name}}_id=(target_id : String?) : String?
        if target_id
          @_{{name}}_delete_on_save = false
          @{{name}}_id = target_id
        else
          @_{{name}}_delete_on_save = true
          @{{name}}_id = nil
        end
      end

      def persist_{{name}}_id : Bool
        # remove any existing rels of this type
        {{klass.id}}::QueryProxy.new("MATCH (n:#{label} {uuid: '#{uuid}'})-[r:{{rel_type.id}}]->(m)", "DELETE r").execute

        if !@_{{name}}_delete_on_save && (target_uuid = {{name}}_id)
          {{klass.id}}::QueryProxy.new("MATCH (n:#{label} {uuid: '#{uuid}'}), (m:#{{{klass.id}}.label} {uuid: '#{target_uuid}'})",
                                       "MERGE (n)-[r:{{rel_type.id}}]->(m)", "RETURN n").execute
        end

        true
      end
    end
  end
end
