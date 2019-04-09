require "../spec_helper"

describe Neo4jModel do
  it "supports belongs_to/has_many" do
    m = Movie.create(name: "Titanic", year: 1997)
    d = Director.create(name: "James Cameron")

    m2 = Movie.create(name: "Aviator", year: 2004)
    d2 = Director.create(name: "Martin Scorsese")
    d2.movies << m2

    m.director = d # this should not take effect until save
    Movie.find!(m.uuid).director.should_not eq d
    Director.find!(d.uuid).movies.to_a.should_not contain m

    m.save
    Movie.find!(m.uuid).director.should eq d
    Director.find!(d.uuid).movies.to_a.should eq [m]

    # can remove by calling .delete on the has_many...
    d.movies.delete(m)
    Movie.find!(m.uuid).director.should_not eq d
    Director.find!(d.uuid).movies.to_a.should_not contain m

    # ... or by setting the belongs_to to nil...
    d.movies << m
    Movie.find!(m.uuid).director.should eq d
    Director.find!(d.uuid).movies.to_a.should eq [m]

    m.director = nil
    m.save
    Movie.find!(m.uuid).director.should_not eq d
    Director.find!(d.uuid).movies.to_a.should_not contain m

    # ... or by setting the belongs_to _id pseudo-attribute to nil...
    d.movies << m
    Movie.find!(m.uuid).director.should eq d
    Director.find!(d.uuid).movies.to_a.should eq [m]

    m.director_id.should_not be_nil
    m.director_id = nil
    m.save
    Movie.find!(m.uuid).director.should be_nil
    Director.find!(d.uuid).movies.to_a.should_not contain m

    # ... or by setting the belongs_to _id pseudo-attribute to ""
    d.movies << m
    Movie.find!(m.uuid).director.should eq d
    Director.find!(d.uuid).movies.to_a.should eq [m]

    m = Movie.find!(m.uuid)
    m.director_id.should_not be_nil
    m.director_id = ""
    m.save
    Movie.find!(m.uuid).director.should be_nil
    Director.find!(d.uuid).movies.to_a.should_not contain m
  end

  it "supports belongs_to_many/has_many" do
    m = Movie.create(name: "Titanic", year: 1997)
    g = Genre.create(name: "Romance")

    m2 = Movie.create(name: "Aviator", year: 2004)
    g2 = Genre.create(name: "Biography")
    g2.movies << m2

    g.movies << m
    Movie.find!(m.uuid).genres.to_a.should eq [g]
    Genre.find!(g.uuid).movies.to_a.should eq [m]

    g.movies.delete(m)
    Movie.find!(m.uuid).genres.to_a.should_not contain g
    Genre.find!(g.uuid).movies.to_a.should_not contain m

    m.genres << g
    Movie.find!(m.uuid).genres.to_a.should eq [g]
    Genre.find!(g.uuid).movies.to_a.should eq [m]

    m.genres.delete(g)
    Movie.find!(m.uuid).genres.to_a.should_not contain g
    Genre.find!(g.uuid).movies.to_a.should_not contain m
  end

  it "supports has_one/belongs_to_many" do
    actor = Actor.create(name: "Leonardo DiCaprio")
    agent = Agent.create(name: "Joe Smith")

    actor2 = Actor.create(name: "Cate Blanchett")
    agent2 = Agent.create(name: "Jane Smith")
    agent2.actors << actor2

    actor.agent = agent # this should not take effect until save
    Actor.find!(actor.uuid).agent.should_not eq agent
    Agent.find!(agent.uuid).actors.to_a.should_not contain actor

    actor.save
    Actor.find!(actor.uuid).agent.should eq agent
    Agent.find!(agent.uuid).actors.to_a.should eq [actor]

    agent.actors.delete(actor)
    Actor.find!(actor.uuid).agent.should be_nil
    Agent.find!(agent.uuid).actors.to_a.should_not contain actor

    agent.actors << actor
    Actor.find!(actor.uuid).agent.should eq agent
    Agent.find!(agent.uuid).actors.to_a.should eq [actor]

    actor.agent = nil
    actor.save
    Actor.find!(actor.uuid).agent.should be_nil
    Agent.find!(agent.uuid).actors.to_a.should_not contain actor

    agent.actors << actor
    Actor.find!(actor.uuid).agent.should eq agent
    Agent.find!(agent.uuid).actors.to_a.should eq [actor]

    actor.agent_id.should_not be_nil
    actor.agent_id = nil
    # puts "before save"
    actor.save
    # puts "after save"
    Actor.find!(actor.uuid).agent.should be_nil
    Agent.find!(agent.uuid).actors.to_a.should_not contain actor

    agent.actors << actor
    Actor.find!(actor.uuid).agent.should eq agent
    Agent.find!(agent.uuid).actors.to_a.should eq [actor]

    actor = Actor.find!(actor.uuid)
    actor.agent_id.should_not be_nil
    actor.agent_id = ""
    actor.save
    Actor.find!(actor.uuid).agent.should be_nil
    Agent.find!(agent.uuid).actors.to_a.should_not contain actor
  end
end
