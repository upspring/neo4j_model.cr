module Neo4j
  module Model
    macro included
      property _undeclared_properties = Neo4j::QueryProxy::CypherParamsHash.new
    end

    def []?(key : Symbol | String) : Neo4j::Type?
      {% for var in @type.instance_vars.reject { |v| v.name =~ /^_/ } %}
        return @{{var}}.as(Neo4j::Type?) if key.to_s == "{{var}}"
      {% end %}
      _undeclared_properties[key.to_s]? || _node.properties[key.to_s]?
    end

    def [](key : Symbol | String) : Neo4j::Type?
      raise IndexError.new unless _undeclared_properties.has_key?(key.to_s) || _node.properties.has_key?(key.to_s)
      self[key]?
    end

    def []=(key : Symbol | String, val : Neo4j::Type) : Neo4j::Type
      {% for var in @type.instance_vars.reject { |v| v.name =~ /^_/ } %}
      if key.to_s == "{{var}}"
        set_attributes({"{{var}}" => val.as(PropertyType)})
        return val
      end
      {% end %}

      _undeclared_properties[key.to_s] = val
    end

    def get(prop : String | Symbol) : Neo4j::Type?
      self[prop]?
    end

    def get_s(prop : String | Symbol) : String?
      self[prop]?.try &.as?(String)
    end

    def get_i(prop : Symbol | String) : Int32?
      self[prop]?.try &.as?(Int).try &.to_i32
    end

    def get_bool(prop : Symbol | String) : Bool?
      if !(bool = self[prop]?.try &.as?(Bool)).nil?
        bool
      elsif (str = self[prop]?.try &.as?(String))
        str == "true"
      end
    end

    def set(prop : String | Symbol, val : Neo4j::Type)
      self[prop] = val
    end
  end
end
