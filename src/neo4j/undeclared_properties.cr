module Neo4j
  module Model
    macro included
      property _undeclared_properties = Hash(String, Neo4j::Type).new
    end

    def []?(key : Symbol | String)
      {% for var in @type.instance_vars.reject { |v| v.name =~ /^_/ } %}
        return @{{var}} if key.to_s == "{{var}}"
      {% end %}
      _undeclared_properties[key.to_s]? || _node.properties[key.to_s]?
    end

    def [](key : Symbol | String)
      raise IndexError.new unless _undeclared_properties.has_key?(key.to_s) || _node.properties.has_key?(key.to_s)
      self[key]?
    end

    def []=(key : Symbol | String, val : Neo4j::Type) : Neo4j::Type
      {% for var in @type.instance_vars.reject { |v| v.name =~ /^_/ } %}
      if key.to_s == "{{var}}"
        set_attributes({"{{var}}" => val})
        return val
      end
      {% end %}

      _undeclared_properties[key.to_s] = val
    end

    def get(prop : String | Symbol)
      self[prop]?
    end

    def get_i(key : Symbol | String)
      self[key]?.try &.as?(Int)
    end

    def get_bool(key : Symbol | String)
      self[key]?.try &.as?(Bool)
    end

    def set(prop : String | Symbol, val : Neo4j::Type)
      self[prop] = val
    end
  end
end
