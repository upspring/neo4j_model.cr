require "neo4j"

module Neo4j
  module Model
    macro included
      # equivalent of ActiveNode has_one :out
      macro has_one(klass, reltype, *, name = "", unique = true)
        \{% name = (name == "" ? klass.id.underscore : name) %}
        def \{{name.id}}
          \{{klass.id}}.execute("MATCH (n:#{label})-[r:\{{reltype.id}}]->(m:#{\{{klass.id}}.label}) RETURN m, r LIMIT 1").each_with_rel do |obj, rel|
            obj._rel = rel ; return obj
          end
        end
      end # macro has_one

      # equivalent of ActiveNode has_many :out
      macro has_many(klass, reltype, *, name = "", unique = true)
        \{% name = (name == "" ? klass.id.underscore + 's' : name) %}
        def \{{name.id}}
          \{{klass.id}}.execute("MATCH (n:#{label})-[r:\{{reltype.id}}]->(m:#{\{{klass.id}}.label}) RETURN m, r LIMIT #{@@limit}")
        end
      end # macro has_many

      # equivalent of ActiveNode has_one :in
      macro belongs_to(klass, reltype, *, name = "", unique = true)
        \{% name = (name == "" ? klass.id.underscore : name) %}
        def \{{name.id}}
        \{{klass.id}}.execute("MATCH (n:#{label})<-[r:\{{reltype.id}}]-(m:#{\{{klass.id}}.label}) RETURN m, r LIMIT 1").each_with_rel do |obj, rel|
            obj._rel = rel ; return obj
          end
        end
      end # macro belongs_to

      # equivalent of ActiveNode has_many :in
      macro belongs_to_many(klass, reltype, *, name = "", unique = true)
        \{% name = (name == "" ? klass.id.underscore + 's' : name) %}
        def \{{name.id}}
          \{{klass.id}}.execute("MATCH (n:#{label})<-[r:\{{reltype.id}}]-(m:#{\{{klass.id}}.label}) RETURN m, r LIMIT #{@@limit}")
        end
      end # macro belongs_to_many
    end
  end
end
