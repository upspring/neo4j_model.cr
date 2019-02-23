module Neo4jModel
  class Relationship
    getter _relationship : Neo4j::Relationship
    getter _undeclared_properties = Hash(String, Neo4j::Type).new

    def initialize(@_relationship)
    end

    def []?(key : Symbol | String)
      _undeclared_properties[key.to_s]? || _relationship.properties[key.to_s]?
    end

    def [](key : Symbol | String)
      raise IndexError.new unless _undeclared_properties.has_key?(key.to_s) || _relationship.properties.has_key?(key.to_s)
      self[key]?
    end

    def []=(key : Symbol | String, val : Neo4j::Type) : Neo4j::Type
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

    def set(prop : String | Symbol, val : Neo4j::Type)
      self[prop] = val
    end
  end
end

module Neo4j
  module Model
    macro included
      class Relationship < Neo4jModel::Relationship
        getter _query_proxy : Neo4jModel::QueryProxy({{@type.id}})

        def initialize(@_relationship, @_query_proxy)
        end

        def save
          if _undeclared_properties.keys.size > 0
            _query_proxy.set(_undeclared_properties)
            _query_proxy.build_cypher_query(_query_proxy.rel_variable_name)
            _query_proxy.execute(skip_build: true)
          end
        end
      end
    end
  end
end
