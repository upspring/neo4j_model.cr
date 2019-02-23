require "../spec_helper"

# describe Neo4jModel do
#   it "supports chaining and variable renaming on associations" do
#     a = Actor.create(name: "Leonardo DiCaprio")
#     a2 = Actor.create(name: "John DiMaggio")

#     m = Movie.create(name: "Titanic", year: 1998)
#     m2 = Movie.create(name: "Aviator", year: 2004)
#     m3 = Movie.create(name: "Futurama: Bender's Big Score", year: 2007)

#     g = Genre.create(name: "Romance")
#     g2 = Genre.create(name: "Biography")
#     g3 = Genre.create(name: "Animation")

#     # FIXME: we do want scoped create to work eventually
#     # m = g.movies.create(name: "Titanic")

#     g.movies << m
#     g2.movies << m2
#     g3.movies << m3

#     m.genres.to_a.should eq [g]
#     m2.genres.to_a.should eq [g2]

#     m.actors << a
#     m2.actors << a
#     m3.actors << a2

#     a.movies.count.should eq 2
#     a2.movies.count.should eq 1

#     g.movies.actors.to_a.size.should eq 1
#     g.movies.actors.to_a.should_not contain(a2)
#     g.movies.actors.to_a.should eq [a]

#     a.movies.genres.to_a.size.should eq 2
#     a.movies.genres.to_a.should_not contain(g3)
#     a.movies.genres.to_a.should contain(g)
#     a.movies.genres.to_a.should contain(g2)

#     # also test variable renaming
#     a.movies(:m).where("m.year = 2004").to_a.should eq [m2]
#     g2.movies(:m).where("m.year = 2004").to_a.should eq [m2]
#     m.actors(:a).where("a.name = 'Leonardo DiCaprio'").to_a.should eq [a]

#     # variable renaming AND chaining
#     a.movies(:m).where("m.year = 2004").genres.to_a.should eq [g2]
#     g2.movies(:m).where("m.year = 2004").actors.to_a.should eq [a]
#   end
# end
