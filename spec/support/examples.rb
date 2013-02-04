shared_examples_for "a serializable bson document" do

  it "deserializes the document" do
    Moped::BSON::Document.deserialize(io).should eq(doc)
  end

  it "serializes the document" do
    Moped::BSON::Document.serialize(doc).should eq(raw.force_encoding('binary'))
  end
end
