require "../spec_helper"

describe Neo4jModel do
  it "supports String and Int properties" do
    m = Movie.new
    m.name = "Aviator"
    m.year = 2004
    m.save.should be_true
  end

  it "supports Array(String) properties" do
    m = Movie.create(name: "Aviator", year: 2004)

    val = ["tag1", "tag2"]

    m.tags = val
    m.save.should be_true

    m = Movie.find!(m.uuid)

    m.tags.should eq val
  end

  it "supports Hash(String, String) properties" do
    m = Movie.create(name: "Aviator", year: 2004)

    val = {"key" => "val"}

    m.metadata = val
    m.save.should be_true

    m = Movie.find!(m.uuid)

    m.metadata.should eq val
  end

  it "updates timestamps if present" do
    m = Movie.create(name: "Titanic", year: 1997)
    m = Movie.find!(m.uuid)
    m.created_at.not_nil!.year.should be > 2001
    m.updated_at.not_nil!.year.should be > 2001
  end

  it "can get/set undeclared String, Int and Bool properties via hash" do
    m = Movie.create(name: "Titanic", year: 1997)
    m["str-1"] = "asdf"
    m["int"] = 123
    m["bool"] = true

    # should work immediately...
    m["str-1"].should eq "asdf"
    m["int"].as(Int).should eq 123
    m["bool"].as(Bool).should be_true
    m.get_i("int").should eq 123
    m.get_bool("bool").should be_true

    # ... as well as after a save/find cycle
    m.save
    m = Movie.find!(m.uuid)
    m["str-1"].should eq "asdf"
    m["int"].as(Int).should eq 123
    m["bool"].as(Bool).should be_true
    m.get_i("int").should eq 123
    m.get_bool("bool").should be_true
    expect_raises(IndexError) { m["property-that-doesnt-exist"] }

    # should also work for regular (named) properties
    m["name"].should eq "Titanic"
    m["year"].should eq 1997
    m["released"].should be_true
    m.get("name").should eq "Titanic"
    m.get_i("year").should eq 1997
    m.get_bool("released").should be_true
  end

  it "supports reload (re-read properties from database)" do
    m = Movie.create(name: "Titanic", year: 1997)
    m.year = 12345
    m.reload
    m.year.should eq 1997
  end

  # it "should get/set undeclared String, Int and Bool properties via hash" do
  #   m = Movie.create(name: "Titanic", year: 1997)
  #   m.update_properties({ "str" => "asdf", "int" => 123, "bool" => true })
  #   m["str"].should eq "asdf"
  #   m["int"].as(Int).should eq 123
  #   m["bool"].as(Bool).should be_true
  #   m.get_i("int").should eq 123
  #   m.get_bool("bool").should be_true
  # end

  # it "should get/set undeclared String, Int and Bool properties via named tuple" do
  #   m = Movie.create(name: "Titanic", year: 1997)
  #   m.update_properties(str: "asdf", int: 123, bool: true)
  #   m["str"].should eq "asdf"
  #   m["int"].as(Int).should eq 123
  #   m["bool"].as(Bool).should be_true
  #   m.get_i("int").should eq 123
  #   m.get_bool("bool").should be_true
  # end
end
