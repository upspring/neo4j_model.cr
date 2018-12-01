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

  it "should implement #count" do
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
end
