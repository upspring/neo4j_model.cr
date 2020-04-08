require "./spec_helper"

describe Neo4jModel do
  it "supports equality by uuid comparison" do
    m1 = Movie.new(name: "Test")
    m2 = Movie.new(name: "Test")

    m1.uuid.should_not eq m2.uuid
    m1.should_not eq m2

    m1._uuid = m2._uuid
    m1.uuid.should eq m2.uuid
    m1.should eq m2
  end
end
