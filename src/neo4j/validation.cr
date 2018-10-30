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

    def valid?
      true # we don't support validations yet, so... it's not *wrong*...
    end
  end
end
