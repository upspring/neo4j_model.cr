require "../spec_helper"

describe Neo4jModel do
  it "supports association chaining" do
    Genre.delete_all
    Movie.delete_all
    Actor.delete_all

    g = Genre.create(name: "Romance")

    # FIXME: we do want scoped create to work eventually
    # m = g.movies.create(name: "Titanic")
 
    m = Movie.create(name: "Titanic")
    g.movies << m
    m.genres.to_a.should contain(g)

    a = Actor.create(name: "Leonardo DiCaprio")
    b = Actor.create(name: "John DiMaggio")
    m.actors << a
    a.movies.to_a.should contain(m)

    g.movies.actors.to_a.should contain(a)
    g.movies.actors.to_a.should_not contain(b)
  end
end
