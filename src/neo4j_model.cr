require "json"
require "neo4j"
require "./neo4j/base"
require "./neo4j/persistence"
require "./neo4j/undeclared_properties"
require "./neo4j/validation"
require "./neo4j/callbacks"
require "./neo4j/querying"
require "./neo4j/scopes"
require "./neo4j/relationship"
require "./neo4j/associations/belongs_to"
require "./neo4j/associations/has_many"
require "./neo4j/associations/has_one"
require "./neo4j/associations/belongs_to_many"

# TODO: Write documentation for `Neo4jModel`
module Neo4jModel
  VERSION = "0.9.1"

  class Settings
    property logger : Logger
    property neo4j_bolt_url : String = ENV["NEO4J_URL"]? || "bolt://neo4j@localhost:7687"
    property pool_size : Int32 = 25

    def initialize
      @logger = Logger.new nil
      @logger.progname = "Neo4jModel"
    end
  end

  def self.settings
    @@settings ||= Settings.new
  end
end
