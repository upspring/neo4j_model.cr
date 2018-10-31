require "neo4j"

module Neo4j
  module Model
    macro included
      # equivalent of ActiveNode has_one :out
      macro has_one(klass, *, rel_type, name = "", unique = true)
        \{% name = (name == "" ? klass.id.underscore : name) %}
        def \{{name.id}}
          \{{klass.id}}::QueryProxy.new("MATCH (n:#{label})-[r:\{{rel_type.id}}]->(m:#{\{{klass.id}}.label})", "RETURN m, r LIMIT 1").limit(1).each_with_rel do |obj, rel|
            obj._rel = rel ; return obj
          end
        end
      end

      # equivalent of ActiveNode has_many :out
      macro has_many(klass, *, rel_type, name = "", unique = true)
        \{% name = (name == "" ? klass.id.underscore + 's' : name) %}
        def \{{name.id}}
          \{{klass.id}}::QueryProxy.new("MATCH (n:#{label})-[r:\{{rel_type.id}}]->(m:#{\{{klass.id}}.label})", "RETURN m, r")
        end
      end

      # equivalent of ActiveNode has_one :in
      macro belongs_to(klass, *, rel_type, name = "", unique = true)
        \{% name = (name == "" ? klass.id.underscore : name) %}
        def \{{name.id}}
          \{{klass.id}}::QueryProxy.new("MATCH (n:#{label})<-[r:\{{rel_type.id}}]-(m:#{\{{klass.id}}.label})", "RETURN m, r").each_with_rel do |obj, rel|
            obj._rel = rel ; return obj
          end
        end
      end

      # equivalent of ActiveNode has_many :in
      macro belongs_to_many(klass, *, rel_type, name = "", unique = true)
        \{% name = (name == "" ? klass.id.underscore + 's' : name) %}
        def \{{name.id}}
          \{{klass.id}}::QueryProxy.new("MATCH (n:#{label})<-[r:\{{rel_type.id}}]-(m:#{\{{klass.id}}.label})", "RETURN m, r")
        end
      end
    end
  end
end
