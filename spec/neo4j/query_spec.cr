require "../spec_helper"

describe Neo4jModel do
  it "supports where queries with exact matching" do
    d = Director.create(name: "James Cameron")
    m = Movie.create(name: "Titanic", year: 1997)
    m.director = d
    n = Movie.create(name: "The Aviator", year: 2004)

    Movie.where(name: "Titanic").to_a.should contain(m)
    Movie.where(name: "Titanic").to_a.should_not contain(n)
    Movie.where(year: 1997).to_a.should contain(m)
    Movie.where(year: 1997).to_a.should_not contain(n)

    # FIXME: this should work...
    # Movie.where(director_id: d.id).to_a.should contain(m)
    Movie.where(director_id: d.id).to_a.should_not contain(n)
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
end
