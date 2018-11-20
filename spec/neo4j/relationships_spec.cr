require "../spec_helper"

describe Neo4jModel do
  it "rel should allow getting and setting properties" do
    m = Movie.create(name: "Titanic", year: 1997)
    m2 = Movie.create(name: "The Aviator", year: 2004)
    d = Director.create(name: "James Cameron")
    d.movies << m
    d.movies << m2

    d.movies.each_with_rel do |movie, r|
      r.set("prop1", "val1") if movie == m
      r.set("prop1", "val2") if movie == m2
      r.save
    end

    d.movies.each_with_rel do |movie, r|
      r.get("prop1").should eq "val1" if movie == m
      r.get("prop1").should eq "val2" if movie == m2
    end

    m = Movie.find!(m.uuid)
    m2 = Movie.find!(m2.uuid)
    m.director.not_nil!.rel.not_nil!.get("prop1").should eq "val1"
    m2.director.not_nil!.rel.not_nil!.get("prop1").should eq "val2"
  end
end
