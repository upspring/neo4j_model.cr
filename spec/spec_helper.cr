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

  property tags : Array(String)?
  property metadata : Hash(String, String)?

  property created_at : Time? = Time.utc_now
  property updated_at : Time? = Time.utc_now
end

class Director
  include Neo4j::Model

  has_many Movie, rel_type: :directed
  has_one Agent, rel_type: :contracts

  property name : String?
end

class Actor
  include Neo4j::Model

  has_many Movie, rel_type: :acted_in
  has_one Agent, rel_type: :contracts

  has_many Studio, name: :studios_worked_with, rel_type: :worked_with

  property name : String?
end

class Studio
  include Neo4j::Model

  has_many Movie, rel_type: :owns

  property name : String?
end

class Genre
  include Neo4j::Model

  has_many Movie, rel_type: :includes

  property name : String?
end

class Agent
  include Neo4j::Model

  belongs_to_many Director, rel_type: :contracts
  belongs_to_many Actor, rel_type: :contracts

  property name : String?
end
