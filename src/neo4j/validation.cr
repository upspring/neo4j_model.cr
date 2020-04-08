module Neo4j
  class Error
    property property : Symbol
    property message : String

    def initialize(@property, @message)
    end

    def to_s
      "#{@property} #{@message}"
    end
  end

  module Model
    macro included
      # use leading underscore to indicate a property/ivar that should *not* be persisted to neo4j
      property _errors = [] of Neo4j::Error
    end

    def errors
      @_errors
    end

    def valid?(*, skip_callbacks = false)
      unless skip_callbacks
        unless @@_before_validation_callback.call(self)
          Neo4jModel::Log.debug { "before_validation callback returned false, aborting" }
          return false
        end
      end

      # TODO: do some stuff here

      unless skip_callbacks
        unless @@_after_validation_callback.call(self)
          Neo4jModel::Log.debug { "after_validation callback returned false, aborting" }
          return false
        end
      end

      true # we don't support validations yet, so... it's not *wrong*...
    end
  end
end
