def session
  return @session if defined? @session
  @session = Moped::Session.new %w[ 127.0.0.1:27017 ], database: "moped_test"
end

session.with database: "system" do |system|
  system[:indexes].insert(
    name: "moped_test_people_id",
    ns: "moped_test.people",
    key: [[:id, 1]]
  )
end
