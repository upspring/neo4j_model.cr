require "../spec_helper"

describe Neo4jModel do
  it "should support String and Int properties" do
    m = Movie.new
    m.name = "Aviator"
    m.year = 2004
    m.save.should be_true
  end

  it "should support Array(String) properties" do
    m = Movie.create(name: "Aviator", year: 2004)

    val = ["test1", "test2"]

    # temporary
    m.example_array = val
    m.save.should be_true

    m = Movie.find!(m.uuid)

    # temporary
    m.example_array.should eq val
  end

  it "should support Hash(String, String) properties" do
    m = Movie.create(name: "Aviator", year: 2004)

    val = {"test1" => "test2"}

    # temporary
    m.example_hash = val
    m.save.should be_true

    m = Movie.find!(m.uuid)

    # temporary
    m.example_hash.should eq val
  end

  it "should update timestamps if present" do
    m = Movie.create(name: "Titanic", year: 1997)
    m = Movie.find!(m.uuid)
    m.created_at.not_nil!.year.should be > 2001
    m.updated_at.not_nil!.year.should be > 2001
  end
end
