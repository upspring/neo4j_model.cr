require "../spec_helper"

describe Neo4jModel do
  it "rel should allow getting and setting properties" do
    m = Movie.create(name: "Titanic", year: 1997)
    m2 = Movie.create(name: "The Aviator", year: 2004)
    d = Director.create(name: "James Cameron")
    d.movies << m
    d.movies << m2

    d.movies.each_with_rel do |movie, r|
      if movie == m
        r.set("prop1", "val1")
      end
      if movie == m2
        r.set("prop1", "val2")
        r["str"] = "string"
        r["int"] = 123
        r["bool"] = true
      end
      r.save
    end

    d.movies.each_with_rel do |movie, r|
      if movie == m
        r.get("prop1").should eq "val1"
      end
      if movie == m2
        r.get("prop1").should eq "val2"
        r["str"].should eq "string"
        r.get_i("int").should eq 123
        r.get_bool("bool").should eq true
      end
    end

    m = Movie.find!(m.uuid)
    m2 = Movie.find!(m2.uuid)
    m.director.not_nil!.rel.not_nil!.get("prop1").should eq "val1"
    m2.director.not_nil!.rel.not_nil!.get("prop1").should eq "val2"
  end
end
