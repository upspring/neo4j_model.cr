require "./neo4j/base"
require "./neo4j/persistence"
require "./neo4j/validation"
require "./neo4j/callbacks"
require "./neo4j/querying"
require "./neo4j/scopes"
require "./neo4j/associations"

# TODO: Write documentation for `Neo4jModel`
module Neo4jModel
  VERSION = "0.7.0"

  class Settings
    property logger : Logger

    def initialize
      @logger = Logger.new nil
      @logger.progname = "Neo4jModel"
    end
  end

  def self.settings
    @@settings ||= Settings.new
  end
end
