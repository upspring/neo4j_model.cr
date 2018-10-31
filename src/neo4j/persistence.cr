require "neo4j"
require "json"

module Neo4j
  module Model
    # supported property types (could expand in the future)
    alias Integer = Int8 | Int16 | Int32 | Int64
    alias PropertyType = Nil | Bool | String | Integer | Float64 | Array(PropertyType) | Hash(String, PropertyType)

    alias Changeset = NamedTuple(old_value: Neo4j::Type, new_value: Neo4j::Type)

    macro included
      property _changes = Hash(Symbol, Changeset).new
    end

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
        set_attributes(from node: db_version.node)
      end
    end

    def update(hash : Hash(String, PropertyType))
      set_attributes(hash)
      save
    end

    def update_columns(hash : Hash(String, PropertyType))
      set_attributes(hash)
      save(skip_callbacks: true)
    end

    def save(*, skip_callbacks = false) # FIXME: no callbacks to skip yet
      {% for var in @type.instance_vars.reject { |v| v.id =~ /^_/ } %}
        {% if var.type <= Array || (var.type.union? && var.type.union_types.includes?(Array)) %}
        if (old_value = @_node.properties["{{var}}"]?) != (new_value = @{{var}}.to_json)
          @_changes[:{{var}}] = { old_value: old_value, new_value: new_value }
        end
        {% elsif var.type <= Hash || (var.type.union? && var.type.union_types.includes?(Hash)) %}
        hash_with_string_keys = {} of String => Type
        @{{var}}.each { |key, value| hash_with_string_keys[key.to_s] = value }
        if (old_value = @_node.properties["{{var}}"]?) != (new_value = hash_with_string_keys.to_json)
          @_changes[:{{var}}] = { old_value: old_value, new_value: new_value }
        end
        {% elsif var.type <= Time || (var.type.union? && var.type.union_types.includes?(Time)) %}
        if (local_var = @{{var}}) # remember, this type of guard doesn't work with instance vars, need to snapshot to local var
          if (old_value = @_node.properties["{{var}}"]?) != (new_value = local_var.epoch)
            @_changes[:{{var}}] = { old_value: old_value, new_value: new_value }
          end
        elsif (old_value = @_node.properties["{{var}}"]?) != (new_value = nil)
          @_changes[:{{var}}] = { old_value: old_value, new_value: new_value }
        end
        {% else %}
        if (old_value = @_node.properties["{{var}}"]?) != (new_value = @{{var}})
          @_changes[:{{var}}] = { old_value: old_value, new_value: new_value }
        end
        {% end %}
      {% end %}

      # then persist changeset to database
      @_changes.reject!(:created_at) # reject changes to created_at once set

      unless @_changes.empty?
        if (t = @created_at) && !@_node.properties["created_at"]?
          @_changes[:created_at] = { old_value: nil, new_value: t.epoch }
        end
        if (t = @updated_at)
          @_changes[:updated_at] = { old_value: t.epoch, new_value: (@updated_at = Time.utc_now).epoch }
        end

        # values = @_changes.transform_values { |v| v[:new_value] } # why doesn't this work?
        values = Hash.zip(@_changes.keys, @_changes.values.map { |v| v[:new_value] })

        if persisted?
          self.class.where(uuid: @_uuid).set(values)
        else
          values[:uuid] = @_uuid
          self.class.create(values)
        end
      end

      # finally, update internal node representation
      @_changes.each { |prop, changeset| @_node.properties["#{prop}"] = changeset[:new_value] }
      @_changes.clear

      true # FIXME
    end
  end
end
