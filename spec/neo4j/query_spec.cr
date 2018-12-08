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
    d = Director.create(name: "James Cameron")
    m1 = Movie.create(name: "Titanic", year: 1997)
    m1.director = d
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

    Director.query_proxy.new("MATCH (Movie {name: 'Titanic'})<--(d:Director)", "RETURN d").query_as(:d).to_a.should eq [d]
  end

  it "supports where queries with arrays" do
    d = Director.create(name: "James Cameron")
    m = Movie.create(name: "Titanic", year: 1997)
    m.director = d
    m2 = Movie.create(name: "The Aviator", year: 2004)
    m3 = Movie.create(name: "Futurama: Bender's Big Score", year: 2007)

    Movie.where(year: [1997, 2004]).to_a.sort { |a, b| (a.year || 0) <=> (b.year || 0) }.should eq [m, m2]
    Movie.where(name: ["Titanic", "The Aviator"]).to_a.sort { |a, b| (a.year || 0) <=> (b.year || 0) }.should eq [m, m2]
  end

  it "supports count queries" do
    m = Movie.create(name: "Titanic", year: 1997)
    Movie.count.should eq 1

    n = Movie.create(name: "The Aviator", year: 2004)
    Movie.count.should eq 2
  end

  it "supports set_label queries" do
    m = Movie.create(name: "Titanic")
    Movie.count.should eq 1
    Director.count.should eq 0
    Movie.where(name: "Titanic").set_label(:Director).execute
    Director.count.should eq 1
    Movie.count.should eq 1
  end

  it "supports remove_label queries" do
    m = Movie.create(name: "Titanic")
    Movie.where(name: "Titanic").set_label(:Director).execute
    Director.count.should eq 1
    Movie.count.should eq 1
    Movie.where(name: "Titanic").remove_label(:Movie).execute
    Director.count.should eq 1
    Movie.count.should eq 0
  end

  it "should support arbitrary queries with arbitrary return values" do
    m = Movie.create(name: "Titanic", year: 1998)
    m2 = Movie.create(name: "Aviator", year: 2004)
    m3 = Movie.create(name: "Futurama: Bender's Big Score", year: 2007)

    g = Genre.create(name: "Romance")
    g2 = Genre.create(name: "Biography")
    g3 = Genre.create(name: "Animation")

    g.movies << m
    g2.movies << m2
    g3.movies << m3

    q = Movie.query_proxy.new("MATCH (m:Movie)<-[r:includes]-(g:Genre)", "RETURN m, r, g").execute
    q.return_values.size.should eq 3
    genres = q.return_values.map(&.["g"]).map { |node| Genre.new(node.as(Neo4j::Node)) }
    genres.map(&.name).compact.sort.should eq ["Animation", "Biography", "Romance"]
  end

  it "should support DISTINCT return values" do
    m = Movie.create(name: "Titanic", year: 1998)
    m2 = Movie.create(name: "Aviator", year: 2004)

    g = Genre.create(name: "Romance")
    g2 = Genre.create(name: "Biography")

    g.movies << m
    g.movies << m2
    g2.movies << m2

    genres = Movie.all.genres.execute
    genres.to_a.map(&.name).compact.sort.should eq ["Biography", "Romance", "Romance"]
    genres = Movie.all.genres.distinct.execute
    genres.to_a.map(&.name).compact.sort.should eq ["Biography", "Romance"]
  end
end
