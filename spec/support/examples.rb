shared_examples_for "a serializable bson object" do

  it "deserializes the document" do
    BSON::Document.from_bson(io).should eq(doc)
  end

  it "serializes the document" do
    doc.to_bson.should eq(raw.force_encoding('binary'))
  end
end
