require "neo4j"
require "json"

module Neo4j
  module Model
    # supported property types (could expand in the future)
    alias Integer = Int8 | Int16 | Int32 | Int64
    alias PropertyType = Nil | Bool | String | Integer | Float64 | Time | Array(String) | Hash(String, String)

    # if you want to use timestamps, add something like this to your model class
    # (make sure to initialize to a non-nil value, like Time.utc_now)
    #   property created_at : Time? = Time.utc_now
    #   property updated_at : Time? = Time.utc_now

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
        {% if var.type <= Array(String) || (var.type.union? && var.type.union_types.includes?(Array(String))) %}
          self.{{var}} = JSON.parse(node.properties["{{var}}"].as(String)).as_a?.try &.map(&.as_s)
        {% elsif var.type <= Hash(String, String) || (var.type.union? && var.type.union_types.includes?(Hash(String, String))) %}
          self.{{var}} = JSON.parse(node.properties["{{var}}"].as(String)).as_h?.try &.map { |_k, v| v.as_s }
        {% elsif var.type <= Time || (var.type.union? && var.type.union_types.includes?(Time)) %}
          self.{{var}} = Time.unix(node.properties["{{var}}"].as(Int))
        {% elsif var.type <= Bool || (var.type.union? && var.type.union_types.includes?(Bool)) %}
          val = node.properties["{{var}}"]
          self.{{var}} = val.nil? ? nil : val.as(Bool)
        {% else %}
          self.{{var}} = node.properties["{{var}}"].as(typeof(@{{var}}))
        {% end %}
      else
        self.{{var}} = nil
      end
      {% end %}

      true
    end

    def set_attributes(hash : Hash(String, PropertyType))
      {% for var in @type.instance_vars.reject { |v| v.name =~ /^_/ } %}
        if hash.has_key?("{{var}}")
          if hash["{{var}}"].nil?
            self.{{var}} = nil
          else
            {% if var.type <= Bool || (var.type.union? && var.type.union_types.includes?(Bool)) %}
              if (val = hash["{{var}}"]?)
                if val.is_a?(Bool)
                  self.{{var}} = hash["{{var}}"].as(Bool)
                elsif val.is_a?(Int)
                  self.{{var}} = hash["{{var}}"] == 1
                elsif val.is_a?(String)
                  self.{{var}} = ["1", "true"].includes?(hash["{{var}}"].as(String).downcase)
                end
              end
            {% elsif var.type <= Integer || (var.type.union? && (var.type.union_types.includes?(Int8) || var.type.union_types.includes?(Int16) || var.type.union_types.includes?(Int32) || var.type.union_types.includes?(Int64))) %}
              if (val = hash["{{var}}"]?)
                if val.is_a?(Int)
                  self.{{var}} = hash["{{var}}"].as(typeof(@{{var}}))
                elsif val.is_a?(String)
                  self.{{var}} = hash["{{var}}"].as(String).to_i
                end
              end
            {% elsif var.type <= Time || (var.type.union? && var.type.union_types.includes?(Time)) %}
              if (val = hash["{{var}}"]?)
                if val.is_a?(Time)
                  self.{{var}} = hash["{{var}}"].as(Time)
                else
                  # FIXME: interpret string or integer values
                end
              end
            {% elsif var.type <= Array(String) || (var.type.union? && var.type.union_types.includes?(Array(String))) %}
              if (val = hash["{{var}}"]?)
                if val.is_a?(Array)
                  self.{{var}} = hash["{{var}}"].as(typeof(@{{var}}))
                else
                  # FIXME: interpret string values?
                end
              end
            {% elsif var.type <= Hash(String, String) || (var.type.union? && var.type.union_types.includes?(Hash(String, String))) %}
              if (val = hash["{{var}}"]?)
                if val.is_a?(Hash)
                  self.{{var}} = hash["{{var}}"].as(typeof(@{{var}}))
                else
                  # FIXME: interpret string values?
                end
              end
            {% elsif var.type <= String || (var.type.union? && var.type.union_types.includes?(String)) %}
              if hash.has_key?("{{var}}")
                self.{{var}} = hash["{{var}}"].as(typeof(@{{var}}))
              end
            {% end %}
          end
        end
      {% end %}
    end

    def reload : Bool
      return false unless persisted?

      if (db_version = self.class.find(uuid))
        set_attributes(from: db_version._node)
      end

      true
    end

    def update(hash : Hash(String, PropertyType)) : Bool
      set_attributes(hash)
      save
    end

    def update(**params) : Bool
      hash = Hash(String, PropertyType).new
      params.each { |k, v| hash[k.to_s] = v }
      set_attributes(hash)
      save
    end

    def update_columns(**params) : Bool
      hash = Hash(String, PropertyType).new
      params.each { |k, v| hash[k.to_s] = v }
      update_columns(hash)
    end

    def update_columns(hash : Hash(String, PropertyType)) : Bool
      set_attributes(hash)
      save(skip_callbacks: true)
    end

    def save(*, skip_callbacks = false) : Bool
      return false unless valid?(skip_callbacks: skip_callbacks)

      unless skip_callbacks
        unless @@_before_save_callback.call(self)
          puts "before_save callback failed!"
          return false
        end
      end

      {% for var in @type.instance_vars.reject { |v| v.id =~ /^_/ || v.id =~ /_ids?$/ } %}
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
          if (old_value = @_node.properties["{{var}}"]?) != (new_value = local_var.to_unix)
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
      @_changes.reject!(:created_at)                   # reject changes to created_at once set
      @_changes.reject!(:updated_at) if skip_callbacks # reject changes to updated_at when called via update_columns

      unless @_changes.empty?
        {% unless @type.instance_vars.select { |v| v.id == "created_at" }.empty? %}
        if (t = @created_at) && !@_node.properties["created_at"]?
          @_changes[:created_at] = {old_value: nil, new_value: t.to_unix}
        end
        {% end %}
        {% unless @type.instance_vars.select { |v| v.id == "updated_at" }.empty? %}
        if (t = @updated_at)
          @_changes[:updated_at] = {old_value: t.to_unix, new_value: (@updated_at = Time.utc_now).to_unix}
        end
        {% end %}

        # values = @_changes.transform_values { |v| v[:new_value] } # why doesn't this work?
        values = Hash.zip(@_changes.keys, @_changes.values.map { |v| v[:new_value] })

        if persisted?
          self.class.where(uuid: @_uuid).set(values).execute
        else
          values[:uuid] = @_uuid
          self.class.new_create_proxy.set(values).execute.first
          @_persisted = true
        end
      end

      @_changes.each { |prop, changeset| @_node.properties["#{prop}"] = changeset[:new_value] }
      @_changes.clear

      # look for changes to associations and persist as needed
      {% for var in @type.instance_vars.select { |v| v.id =~ /_ids?$/ } %}
        {% if var.type <= Array(String) || (var.type.union? && var.type.union_types.includes?(Array(String))) %}
          if (old_value = @_node.properties["{{var}}"]?) != (new_value = @{{var}}.to_json)
            @_changes[:{{var}}] = { old_value: old_value, new_value: new_value }
            persist_{{var}}
          end
        {% else %}
          if (old_value = @_node.properties["{{var}}"]?) != (new_value = @{{var}})
            @_changes[:{{var}}] = { old_value: old_value, new_value: new_value }
            persist_{{var}}
          end
        {% end %}
      {% end %}

      unless @_changes.empty?
        values = Hash.zip(@_changes.keys, @_changes.values.map { |v| v[:new_value] })
        self.class.where(uuid: @_uuid).set(values).execute
      end

      @_changes.each { |prop, changeset| @_node.properties["#{prop}"] = changeset[:new_value] }
      @_changes.clear

      unless skip_callbacks
        unless @@_after_save_callback.call(self)
          puts "after_save callback failed!"
          return false
        end
      end

      true
    end
  end
end
