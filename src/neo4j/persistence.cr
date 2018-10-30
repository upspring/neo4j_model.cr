require "neo4j"
require "json"

module Neo4j
  module Model
    # supported property types (could expand in the future)
    alias Integer = Int8 | Int16 | Int32 | Int64
    alias PropertyType = Nil | Bool | String | Integer | Float64 | Array(PropertyType) | Hash(String, PropertyType)

    alias Changeset = NamedTuple(property: Symbol, old_value: Neo4j::Type, new_value: Neo4j::Type)

    def persisted?
      @_persisted
    end

    def new_record?
      !@_persisted
    end

    def set_attributes(from node : Neo4j::Node)
      {% for var in @type.instance_vars.reject { |v| v.name =~ /^_/ } %}
      if node.properties.has_key?("{{var}}")
        {% if var.type <= Array || (var.type.union? && var.type.union_types.includes?(Array)) %}
          @{{var}} = JSON.parse(node.properties["{{var}}"].as(String)).as_a.map(&.as_s)
        {% elsif var.type <= Hash || (var.type.union? && var.type.union_types.includes?(Hash)) %}
          @{{var}} = JSON.parse(node.properties["{{var}}"].as(String)).as_h.map { |_k, v| v.as_s }
        {% elsif var.type <= Time || (var.type.union? && var.type.union_types.includes?(Time)) %}
          @{{var}} = Time.epoch(node.properties["{{var}}"].as(Int))
        {% else %}
          @{{var}} = node.properties["{{var}}"].as(typeof(@{{var}}))
        {% end %}
      end
      {% end %}
      true
    end

    def set_attributes(hash : Hash(String, PropertyType))
      {% for var in @type.instance_vars.reject { |v| v.name =~ /^_/ } %}
      if hash.has_key?("{{var}}")
        @{{var}} = hash["{{var}}"].as(typeof(@{{var}}))
      end
      {% end %}
    end

    def reload
      return unless persisted?

      if (db_version = self.class.find(uuid))
        set_attributes(from: db_version.node)
      end
    end

    def update(hash : Hash(String, PropertyType))
      set_attributes(hash)
      save
    end

    def save
      # first, build changeset
      changes = [] of Changeset

      {% for var in @type.instance_vars.reject { |v| v.name =~ /^_/ } %}
        {% if var.type <= Array || (var.type.union? && var.type.union_types.includes?(Array)) %}
        if (old_value = @_node.properties["{{var}}"]?) != (new_value = @{{var}}.to_json)
          changes << { property: :{{var}}, old_value: old_value, new_value: new_value }
        end
        {% elsif var.type <= Hash || (var.type.union? && var.type.union_types.includes?(Hash)) %}
        hash_with_string_keys = {} of String => Type
        @{{var}}.each { |key, value| hash_with_string_keys[key.to_s] = value }
        if (old_value = @_node.properties["{{var}}"]?) != (new_value = hash_with_string_keys.to_json)
          changes << { property: :{{var}}, old_value: old_value, new_value: new_value }
        end
        {% elsif var.type <= Time || (var.type.union? && var.type.union_types.includes?(Time)) %}
        if (local_var = @{{var}}) # remember, this type of guard doesn't work with instance vars, need to snapshot to local var
          if (old_value = @_node.properties["{{var}}"]?) != (new_value = local_var.epoch)
            changes << { property: :{{var}}, old_value: old_value, new_value: new_value }
          elsif (old_value = @_node.properties["{{var}}"]?) != (new_value = nil)
            changes << { property: :{{var}}, old_value: old_value, new_value: new_value }
          end
        end
        {% else %}
        if (old_value = @_node.properties["{{var}}"]?) != (new_value = @{{var}})
          changes << { property: :{{var}}, old_value: old_value, new_value: new_value }
        end
        {% end %}
      {% end %}

      # then persist changeset to database
      if changes.any?
        values = Hash.zip(changes.map(&.[:property]), changes.map(&.[:new_value]))
        values[:uuid] = @_uuid

        if persisted?
          self.class.execute("MATCH (n:#{label}) WHERE (n.uuid = $uuid) SET " + changes.map { |c| "n.`#{c[:property]}` = $#{c[:property]}" }.join(", "), values)
        else
          self.class.execute("CREATE (n) SET n.uuid = $uuid, " + changes.map { |c| "n.`#{c[:property]}` = $#{c[:property]}" }.join(", ") + ", n:#{label}", values)
        end

        true # FIXME
      end

      # finally, update internal node representation
      changes.each { |c| @_node.properties["#{c[:property]}"] = c[:new_value] }
    end
  end
end
