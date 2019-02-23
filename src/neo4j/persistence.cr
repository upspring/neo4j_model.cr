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
      property _changes = Hash(String | Symbol, Changeset).new
    end

    def persisted? : Bool
      @_persisted
    end

    def new_record? : Bool
      !@_persisted
    end

    def touch : Bool
      update_columns(updated_at: Time.utc_now)
    end

    def set_attributes(from node : Neo4j::Node) : Bool
      hash = Hash(String, PropertyType).new
      node.properties.each { |k, v| hash[k] = v.as(PropertyType) }
      set_attributes(hash)
    end

    def set_attributes(hash : Hash(String, PropertyType)) : Bool
      {% for var in @type.instance_vars.reject { |v| v.name =~ /^_/ } %}
        if hash.has_key?("{{var}}")
          if (val = hash["{{var}}"]).nil?
            # set to nil ONLY IF property type includes Nil
            {% if var.type.union? && var.type.union_types.includes?(Nil) %}
              self.{{var}} = nil
            {% end %}
          else
            {% if var.type <= Bool || (var.type.union? && var.type.union_types.includes?(Bool)) %}
              case val
              when Bool
                self.{{var}} = val
              when Int
                self.{{var}} = (val == 1)
              when String
                self.{{var}} = ["1", "true"].includes?(val.downcase)
              else
                raise "Don't know how to convert #{val.class.name} to Bool"
              end
            {% elsif var.type <= Integer || (var.type.union? && (var.type.union_types.includes?(Int8) || var.type.union_types.includes?(Int16) || var.type.union_types.includes?(Int32) || var.type.union_types.includes?(Int64))) %}
              case val
              when Integer
                self.{{var}} = hash["{{var}}"].as(typeof(@{{var}}))
              when String
                if val.blank?
                  {% if var.type.union? && var.type.union_types.includes?(Nil) %}
                    self.{{var}} = nil
                  {% end %}
                else
                  val = hash["{{var}}"].as(String).to_i?
                  if val.nil?
                    {% if var.type.union? && var.type.union_types.includes?(Nil) %}
                      self.{{var}} = nil
                    {% end %}
                  else
                    self.{{var}} = val
                  end
                end
              else
                raise "Don't know how to convert #{val.class.name} to Integer"
              end
            {% elsif var.type <= Time || (var.type.union? && var.type.union_types.includes?(Time)) %}
              case val
              when Time
                self.{{var}} = val.as(Time)
              when Integer
                self.{{var}} = Time.unix(val.as(Int))
              when String
                if val.blank?
                  {% if var.type.union? && var.type.union_types.includes?(Nil) %}
                    self.{{var}} = nil
                  {% end %}
                else
                  # FIXME: interpret string values?
                  raise "Don't know how to convert #{val.class.name} to Time"
                end
              else
                raise "Don't know how to convert #{val.class.name} to Time"
              end
            {% elsif var.type <= Array(String) || (var.type.union? && var.type.union_types.includes?(Array(String))) %}
              case val
              when Array
                self.{{var}} = hash["{{var}}"].as(typeof(@{{var}}))
              when String
                if (array = JSON.parse(val).as_a?)
                  self.{{var}} = array.map(&.as_s)
                end
              else
                raise "Don't know how to convert #{val.class.name} to Array(String)"
              end
            {% elsif var.type <= Hash(String, String) || (var.type.union? && var.type.union_types.includes?(Hash(String, String))) %}
              case val
              when Hash
                self.{{var}} = hash["{{var}}"].as(typeof(@{{var}}))
              when String
                if (h = JSON.parse(val).as_h?)
                  self.{{var}} = h.transform_values { |v| v.to_s }
                end
              else
                raise "Don't know how to convert #{val.class.name} to Hash"
              end
            {% elsif var.type <= String || (var.type.union? && var.type.union_types.includes?(String)) %}
              self.{{var}} = hash["{{var}}"].to_s
            {% end %}
          end
        end
      {% end %}

      # TODO: error checking?
      true
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
          Neo4jModel.settings.logger.debug "before_save callback returned false, aborting"
          return false
        end
      end

      {% for var in @type.instance_vars.reject { |v| v.id =~ /^_/ || v.id =~ /_ids?$/ } %}
        {% if var.type <= Array(String) || (var.type.union? && var.type.union_types.includes?(Array(String))) %}
        if (old_value = @_node.properties["{{var}}"]?) != (new_value = @{{var}}.to_json)
          @_changes[:{{var}}] = { old_value: old_value, new_value: new_value }
        end
        {% elsif var.type <= Hash(String, String) || (var.type.union? && var.type.union_types.includes?(Hash(String, String))) %}
        if (new_hash = @{{var}})
          if (old_value = @_node.properties["{{var}}"]?) != (new_value = new_hash.to_json)
            @_changes[:{{var}}] = { old_value: old_value, new_value: new_value }
          end
        end
        {% elsif var.type <= Time || (var.type.union? && var.type.union_types.includes?(Time)) %}
        if (new_time = @{{var}})
          if (old_value = @_node.properties["{{var}}"]?) != (new_value = new_time.to_unix)
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

      _undeclared_properties.each do |k, v|
        if (old_value = @_node.properties[k]?) != (new_value = v)
          @_changes[k] = {old_value: old_value, new_value: new_value}
        end
      end

      # then persist changeset to database
      @_changes.reject!(:created_at) # reject changes to created_at once set

      unless @_changes.empty?
        {% unless @type.instance_vars.select { |v| v.id == "created_at" }.empty? %}
        if (t = @created_at) && !@_node.properties["created_at"]?
          @_changes[:created_at] = {old_value: nil, new_value: t.to_unix}
        end
        {% end %}
        {% unless @type.instance_vars.select { |v| v.id == "updated_at" }.empty? %}
        if (t = @updated_at)
          @_changes[:updated_at] = {old_value: t.to_unix, new_value: (@updated_at = Time.utc_now).to_unix} unless skip_callbacks
        end
        {% end %}

        # values = @_changes.transform_values { |v| v[:new_value] } # why doesn't this work?
        values = Hash.zip(@_changes.keys, @_changes.values.map { |v| v[:new_value] })

        if persisted?
          self.class.where(uuid: @_uuid).set(values).execute(skip_return: true)
        else
          values[:uuid] = @_uuid
          self.class.new_create_proxy.set(values).execute.first
          @_persisted = true
        end
      end

      @_changes.each { |prop, changeset| @_node.properties["#{prop}"] = changeset[:new_value] }
      @_changes.clear

      # look for changes to associations and persist as needed
      {% for var in @type.instance_vars.select { |v| v.id =~ /_ids?$/ && !(v.id =~ /^_/) } %}
        # has_many/belongs_to_many
        {% if var.type <= Array(String) || (var.type.union? && var.type.union_types.includes?(Array(String))) %}
          if (old_value = @_node.properties["{{var}}"]?) != (new_value = @{{var}}.to_json)
            @_changes[:{{var}}] = { old_value: old_value, new_value: new_value }
            persist_{{var}}
          end

        # belongs_to/has_one
        {% else %}
          # "" (usually from a web form submission) is translated to nil to remove the rel
          @{{var}} = nil if @{{var}} == ""
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
          Neo4jModel.settings.logger.debug "after_save callback returned false, aborting"
          return false
        end
      end

      true
    end
  end
end
