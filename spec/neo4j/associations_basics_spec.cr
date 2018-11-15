require "../spec_helper"

describe Neo4jModel do
  it "supports belongs_to/has_many" do
    Movie.delete_all
    Director.delete_all

    m = Movie.create(name: "Titanic", year: 1997)
    d = Director.create(name: "James Cameron")

    m.director = d # this should not take effect until save
    Movie.find!(m.uuid).director.should_not eq d
    Director.find!(d.uuid).movies.to_a.should_not contain m

    m.save
    Movie.find!(m.uuid).director.should eq d
    Director.find!(d.uuid).movies.to_a.should contain m

    d.movies.delete(m)
    Movie.find!(m.uuid).director.should_not eq d
    Director.find!(d.uuid).movies.to_a.should_not contain m

    d.movies << m
    Movie.find!(m.uuid).director.should eq d
    Director.find!(d.uuid).movies.to_a.should contain m

    m.director = nil
    m.save
    Movie.find!(m.uuid).director.should_not eq d
    Director.find!(d.uuid).movies.to_a.should_not contain m
  end

  it "supports belongs_to_many/has_many" do
    Movie.delete_all
    Genre.delete_all

    m = Movie.create(name: "Titanic", year: 1997)
    g = Genre.create(name: "Romance")

    g.movies << m
    Movie.find!(m.uuid).genres.to_a.should contain g
    Genre.find!(g.uuid).movies.to_a.should contain m

    g.movies.delete(m)
    Movie.find!(m.uuid).genres.to_a.should_not contain g
    Genre.find!(g.uuid).movies.to_a.should_not contain m

    m.genres << g
    Movie.find!(m.uuid).genres.to_a.should contain g
    Genre.find!(g.uuid).movies.to_a.should contain m

    m.genres.delete(g)
    Movie.find!(m.uuid).genres.to_a.should_not contain g
    Genre.find!(g.uuid).movies.to_a.should_not contain m
  end

  it "supports has_one/belongs_to_many" do
    Actor.delete_all
    Agent.delete_all

    actor = Actor.create(name: "Leonardo DiCaprio")
    agent = Agent.create(name: "Joe Smith")

    actor.agent = agent # this should not take effect until save
    Actor.find!(actor.uuid).agent.should_not eq agent
    Agent.find!(agent.uuid).actors.to_a.should_not contain actor

    actor.save
    Actor.find!(actor.uuid).agent.should eq agent
    Agent.find!(agent.uuid).actors.to_a.should contain actor

    agent.actors.delete(actor)
    Actor.find!(actor.uuid).agent.should_not eq agent
    Agent.find!(agent.uuid).actors.to_a.should_not contain actor

    agent.actors << actor
    Actor.find!(actor.uuid).agent.should eq agent
    Agent.find!(agent.uuid).actors.to_a.should contain actor

    actor.agent = nil
    actor.save
    Actor.find!(actor.uuid).agent.should_not eq agent
    Agent.find!(agent.uuid).actors.to_a.should_not contain actor
  end
end
