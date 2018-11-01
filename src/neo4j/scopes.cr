module Neo4j
  module Model
    macro scope(name, proc)
      def self.{{name.id}}(*args)
        {{proc}}.call(*args)
      end

      class QueryProxy
        def {{name.id}}(*args)
          {{proc}}.call(*args)
        end
      end
    end
  end
end
