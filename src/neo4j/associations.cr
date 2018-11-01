require "neo4j"

module Neo4j
  module Model
    # equivalent of ActiveNode has_one :out
    macro has_one(klass, *, rel_type, name = "", unique = true)
      {% name = (name == "" ? klass.id.underscore : name.id) %}
      def {{name.id}}
        ret = nil
        {{klass.id}}::QueryProxy.new("MATCH (n:#{label} {uuid: '#{uuid}'})-[r:{{rel_type.id}}]->(m:#{{{klass.id}}.label})", "RETURN m, r LIMIT 1").limit(1).each_with_rel do |obj, rel|
          obj._rel = rel ; obj
          ret = obj
        end
        ret
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

      def {{name.id}}
        proxy = {{klass.id}}::QueryProxy.new("MATCH (n:#{label} {uuid: '#{uuid}'})-[r:{{rel_type.id}}]->(m:#{{{klass.id}}.label})", "RETURN m, r")
        proxy.add_proxy = {{klass.id}}::QueryProxy.new("MATCH (n:#{label} {uuid: '#{uuid}'}), (m:#{{{klass.id}}.label} {uuid: $target_uuid})",
                                                       "MERGE (n)-[r:{{rel_type.id}}]->(m)", "RETURN m, r")
        proxy.delete_proxy = {{klass.id}}::QueryProxy.new("MATCH (n:#{label} {uuid: '#{uuid}'})-[r:{{rel_type.id}}]->(m:#{{{klass.id}}.label} {uuid: $target_uuid})", "DELETE r")
        proxy
      end
    end

    # equivalent of ActiveNode has_one :in
    macro belongs_to(klass, *, rel_type, name = "", unique = true)
      {% name = (name == "" ? klass.id.underscore : name.id) %}
      def {{name.id}}
        ret = nil
        {{klass.id}}::QueryProxy.new("MATCH (n:#{label} {uuid: '#{uuid}'})<-[r:{{rel_type.id}}]-(m:#{{{klass.id}}.label})", "RETURN m, r").each_with_rel do |obj, rel|
          obj._rel = rel
          ret = obj
        end
        ret
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
      {% classified_name = name.split("_").map(&.capitalize).join("").id %}

      def {{name.id}}
        proxy = {{klass.id}}::QueryProxy.new("MATCH (n:#{label})<-[r:{{rel_type.id}}]-(m:#{{{klass.id}}.label})", "RETURN m, r")
        proxy.add_proxy = {{klass.id}}::QueryProxy.new("MATCH (n:#{label} {uuid: '#{uuid}'}), (m:#{{{klass.id}}.label} {uuid: $target_uuid})",
                                                       "MERGE (n)<-[r:{{rel_type.id}}]-(m)", "RETURN m, r")
        proxy.delete_proxy = {{klass.id}}::QueryProxy.new("MATCH (n:#{label} {uuid: '#{uuid}'})<-[r:{{rel_type.id}}]-(m:#{{{klass.id}}.label} {uuid: $target_uuid})", "DELETE r")
        proxy
      end
    end
  end
end
