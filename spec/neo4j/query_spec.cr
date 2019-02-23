require "../spec_helper"

describe Neo4jModel do
  it "supports where queries with exact matching" do
    d = Director.create(name: "James Cameron")
    m1 = Movie.create(name: "Titanic", year: 1997)
    m1.director = d
    m1.save
    m2 = Movie.create(name: "The Aviator", year: 2004)

    Movie.where(name: "Titanic").to_a.should contain(m1)
    Movie.where(name: "Titanic").to_a.should_not contain(m2)
    Movie.where(year: 1997).to_a.should contain(m1)
    Movie.where(year: 1997).to_a.should_not contain(m2)

    Movie.where(director_id: d.id).to_a.should contain(m1)
    Movie.where(director_id: d.id).to_a.should_not contain(m2)
  end

  it "supports where queries with strings and params" do
    m1 = Movie.create(name: "Titanic", year: 1997)
    m1.save
    m2 = Movie.create(name: "The Aviator", year: 2004)

    Movie.where("movie.name = $name", name: "Titanic").to_a.should contain(m1)
    Movie.where("movie.name = $name", name: "Titanic").to_a.should_not contain(m2)
    Movie.where("movie.year = $year", year: 1997).to_a.should contain(m1)
    Movie.where("movie.year = $year", year: 1997).to_a.should_not contain(m2)
  end

  it "supports custom-built queries" do
    d = Director.create(name: "James Cameron")
    m1 = Movie.create(name: "Titanic", year: 1997)
    m1.director = d
    m1.save
    m2 = Movie.create(name: "The Aviator", year: 2004)

    Director.query_proxy("MATCH (Movie {name: 'Titanic'})<--(d:Director)", "RETURN d").query_as(:d).to_a.should eq [d]
  end

  it "supports where queries with arrays" do
    d = Director.create(name: "James Cameron")
    m = Movie.create(name: "Titanic", year: 1997)
    m.director = d
    m2 = Movie.create(name: "The Aviator", year: 2004)
    m3 = Movie.create(name: "Futurama: Bender's Big Score", year: nil)

    Movie.where(year: [1997, 2004]).order(:year).to_a.should eq [m, m2]
    Movie.where(name: ["Titanic", "The Aviator"]).order(:year).to_a.should eq [m, m2]
    Movie.where(uuid: [m.id, m2.id]).order(:year).to_a.should eq [m, m2]

    # this doesn't work, but it is because neo4j doesn't consider "= null" to be the same as "is null"
    # Movie.where(year: [1997, nil]).order(:name).to_a.should eq [m3, m]

    # maybe make this work someday, since I am CONSTANTLY making this mistake (querying id instead of uuid)
    # Movie.where(id: [m.id, m2.id]).order(:year).to_a.should eq [m, m2]
  end

  it "supports count and pluck queries" do
    m = Movie.create(name: "Titanic", year: 1997)
    Movie.count.should eq 1

    n = Movie.create(name: "The Aviator", year: 2004)
    Movie.count.should eq 2

    Movie.order(:year).pluck(:year).should eq [1997, 2004]
    Movie.order(:year).pluck("year").should eq [1997, 2004]
    Movie.order(:year).pluck(:uuid, :year).should eq [{:uuid => m.uuid, :year => 1997}, {:uuid => n.uuid, :year => 2004}]
    Movie.order(:year).pluck("uuid", "year").should eq [{"uuid" => m.uuid, "year" => 1997}, {"uuid" => n.uuid, "year" => 2004}]
  end

  it "supports set_label/remove_label queries" do
    actor = Actor.create(name: "Leonardo DiCaprio")
    Actor.count.should eq 1
    Agent.count.should eq 0
    Actor.where(uuid: actor.id).set_label(:Agent).execute
    Actor.count.should eq 1
    Agent.count.should eq 1
    agent = Agent.find!(actor.id)
    agent.name.should eq "Leonardo DiCaprio"
    Agent.where(uuid: agent.id).remove_label(:Actor).execute
    Actor.count.should eq 0
    Agent.count.should eq 1
    Actor.find(actor.id).should be_nil

    # double switch
    Agent.where(uuid: agent.id).set_label(:Actor).remove_label(:Agent).execute
    Actor.count.should eq 1
    Agent.count.should eq 0
    Actor.find(actor.id).should_not be_nil
  end

  it "supports arbitrary queries with arbitrary return values" do
    m = Movie.create(name: "Titanic", year: 1998)
    m2 = Movie.create(name: "Aviator", year: 2004)
    m3 = Movie.create(name: "Futurama: Bender's Big Score", year: 2007)

    g = Genre.create(name: "Romance")
    g2 = Genre.create(name: "Biography")
    g3 = Genre.create(name: "Animation")

    g.movies << m
    g2.movies << m2
    g3.movies << m3

    q = Movie.query_proxy("MATCH (m:Movie)<-[r:includes]-(g:Genre)", "RETURN m, r, g").execute
    q.return_values.size.should eq 3
    genres = q.return_values.map(&.["g"]).map { |node| Genre.new(node.as(Neo4j::Node)) }
    genres.map(&.name).compact.sort.should eq ["Animation", "Biography", "Romance"]
  end

  # it "supports DISTINCT return values and counts" do
  #   m = Movie.create(name: "Titanic", year: 1998)
  #   m2 = Movie.create(name: "Aviator", year: 2004)

  #   g = Genre.create(name: "Romance")
  #   g2 = Genre.create(name: "Biography")

  #   g.movies << m
  #   g.movies << m2
  #   g2.movies << m2

  #   genres = Movie.all.genres.execute
  #   genres.map(&.name).compact.sort.should eq ["Biography", "Romance", "Romance"]

  #   Movie.all.genres.count.should eq 3

  #   genres = Movie.all.genres.distinct.execute
  #   genres.map(&.name).compact.sort.should eq ["Biography", "Romance"]

  #   Movie.all.genres.distinct.count.should eq 2

  #   # generated query should ignore the order bys
  #   Movie.all.genres.order(:name).distinct.count.should eq 2
  # end

  it "supports mapping and iteration over results" do
    m = Movie.create(name: "Titanic", year: 1998)
    m2 = Movie.create(name: "Aviator", year: 2004)

    results = Array(String).new
    Movie.all.each { |m| results << m.name }
    results.sort!.should eq ["Aviator", "Titanic"]

    Movie.all.map(&.name).sort.should eq results

    Movie.all[0].should eq Movie.first
  end

  it "supports skip and limit for pagination" do
    m = Movie.create(name: "Aviator", year: 2004)
    m2 = Movie.create(name: "Titanic", year: 1998)
    m3 = Movie.create(name: "Futurama: Bender's Big Score", year: 2007)

    Movie.order(:year).skip(1).limit(1).first.should eq m
  end
end
