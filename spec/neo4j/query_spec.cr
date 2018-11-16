require "../spec_helper"

describe Neo4jModel do
  it "should support where queries with exact matching" do
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
end
