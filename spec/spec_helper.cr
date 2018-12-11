require "spec"
require "logger"
require "../src/neo4j_model"

Spec.before_each { detach_all }

def detach_all
  Movie.with_connection(&.execute "MATCH (n) DETACH DELETE n")
end

class Movie
  include Neo4j::Model

  belongs_to_many Studio, rel_type: :owns
  belongs_to Director, rel_type: :directed
  belongs_to_many Genre, rel_type: :includes
  belongs_to_many Actor, rel_type: :acted_in

  property name : String = "" # make sure we can create non-nilable properties as long as they have default values
  property year : Integer?
  property released : Bool = true

  # help wanted: come up with more plausible example properties
  property example_array : Array(String)?
  property example_hash : Hash(String, String)?

  property created_at : Time? = Time.utc_now
  property updated_at : Time? = Time.utc_now
end

class Director
  include Neo4j::Model

  property name : String?

  has_many Movie, rel_type: :directed
  has_one Agent, rel_type: :contracts
end

class Actor
  include Neo4j::Model

  property name : String?

  has_many Movie, rel_type: :acted_in
  has_one Agent, rel_type: :contracts

  has_many Studio, name: :studios_worked_with, rel_type: :worked_with
end

class Studio
  include Neo4j::Model

  property name : String?

  has_many Movie, rel_type: :owns
end

class Genre
  include Neo4j::Model

  property name : String?

  has_many Movie, rel_type: :includes
end

class Agent
  include Neo4j::Model

  property name : String?

  belongs_to_many Director, rel_type: :contracts
  belongs_to_many Actor, rel_type: :contracts
end
