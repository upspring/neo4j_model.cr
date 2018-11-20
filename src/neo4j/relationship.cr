module Neo4j
  module Model
    macro included
      class Relationship
        getter _relationship : Neo4j::Relationship
        getter _query_proxy : QueryProxy

        def initialize(@_relationship, @_query_proxy)
        end

        def properties
          _relationship.properties
        end

        def get(prop : String | Symbol)
          properties[prop.to_s]?
        end

        def set(prop : String | Symbol, val : Neo4j::Type)
          properties[prop.to_s] = val
        end

        def save
          if (proxy = _query_proxy.as?({{@type.id}}::QueryProxy)) && properties.keys.size > 0
            proxy.set(properties)
            proxy.build_cypher_query(proxy.rel_variable_name)
            proxy.execute(skip_build: true)
          end
        end
      end
    end
  end
end
