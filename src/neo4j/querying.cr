module Neo4j
  module Model
    macro included
      # reopen generic QueryProxy to add a return method for this type
      class Neo4jModel::QueryProxy(T)
        def return(*, {{@type.id.underscore}}) : T? # argument must not have a default value
          proxy = chain Neo4jModel::QueryProxy(T).new
          proxy.first?
        end
      end

      # instance query proxy, used as a base for association queries
      @_query_proxy : Neo4jModel::QueryProxy({{@type.id}})?

      def query_proxy
        if @_query_proxy
          return @_query_proxy.not_nil!
        end

        proxy = self.class.query_proxy("MATCH ({{@type.id.underscore}}:#{label})", "RETURN {{@type.id.underscore}}").query_as(:{{@type.id.underscore}})
        proxy.where(uuid: uuid)
        proxy.uuid = uuid

        @_query_proxy = proxy
      end

      # class query proxy, for finders and other queries not related to an instance
      def self.query_proxy(*args)
        Neo4jModel::QueryProxy(self).new(label, *args)
      end

      def self.new_create_proxy
        query_proxy("CREATE (#{name.underscore}:#{label})").query_as(:{{@type.id.underscore}})
      end

      def self.all
        query_proxy
      end

      def self.first
        query_proxy.first
      end

      def self.first?
        query_proxy.first?
      end

      def self.count
        query_proxy.count
      end

      def self.where(str : String, **params)
        query_proxy.where(str, **params)
      end

      def self.where(**params)
        query_proxy.where(**params)
      end

      def self.where_not(str : String, **params)
        query_proxy.where_not(str, **params)
      end

      def self.where_not(**params)
        query_proxy.where_not(**params)
      end

      def self.order(*params)
        query_proxy.order(*params)
      end

      def self.order(**params)
        query_proxy.order(**params)
      end

      def self.find!(uuid : String?)
        raise "find! called with nil uuid param" unless uuid

        where(uuid: uuid).first
      end

      def self.find(uuid : String?)
        return nil unless uuid

        where(uuid: uuid).first?
      end

      def self.find_by(**params)
        where(**params).first?
      end

      def self.find_by!(**params)
        where(**params).first
      end

      def self.find_or_initialize_by(**params)
        find_by(**params) || new(**params)
      end

      def self.find_or_create_by(**params)
        find_by(**params) || create(**params)
      end

      def self.create(params : Hash)
        obj = new(params)
        obj.save
        obj
      end

      def self.create(**params)
        obj = new(**params)
        obj.save
        obj
      end

      def self.delete_all
        query_proxy.delete_all
      end

      def self.clear
        delete_all
      end

      # FIXME: this version should run callbacks
      def self.destroy_all
        query_proxy.destroy_all
      end
    end # macro included

    def destroy
      self.class.query_proxy("MATCH (n:#{label} {uuid: '#{uuid}'})", "DETACH DELETE n").execute
      true # FIXME: check for errors
    end
  end
end
