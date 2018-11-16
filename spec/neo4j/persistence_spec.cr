require "../spec_helper"

describe Neo4jModel do
  it "should update timestamps if present" do
    m = Movie.new(name: "Titanic", year: 1997)
    m.save.should be_true

    m = Movie.find!(m.uuid)
    m.created_at.not_nil!.year.should be > 2001
    m.updated_at.not_nil!.year.should be > 2001
  end
end
