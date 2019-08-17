module Neo4j
  module Model
    macro included
      class Relationship
        getter _relationship : Neo4j::Relationship
        getter _query_proxy : QueryProxy

        # there will be declared properties at some point
        getter _undeclared_properties = Hash(String, Neo4j::Value).new

        def initialize(@_relationship, @_query_proxy)
        end

        def []?(key : Symbol | String)
          _undeclared_properties[key.to_s]? || _relationship.properties[key.to_s]?
        end

        def [](key : Symbol | String)
          raise IndexError.new unless _undeclared_properties.has_key?(key.to_s) || _relationship.properties.has_key?(key.to_s)
          self[key]?
        end

        def []=(key : Symbol | String, val : Neo4j::Value) : Neo4j::Value
          _undeclared_properties[key.to_s] = val
        end

        def get(prop : String | Symbol)
          self[prop]?
        end

        def get_i(prop : Symbol | String) : Int32?
          self[prop]?.try &.as?(Int).try &.to_i32
        end

        def get_bool(prop : Symbol | String) : Bool?
          self[prop]?.try &.as?(Bool)
        end

        def set(prop : String | Symbol, val : Neo4j::Value)
          self[prop] = val
        end

        def save
          if (proxy = _query_proxy.as?({{@type.id}}::QueryProxy)) && _undeclared_properties.keys.size > 0
            proxy.set(_undeclared_properties)
            proxy.build_cypher_query(proxy.rel_variable_name)
            proxy.execute(skip_build: true)
          end
        end
      end
    end
  end
end
