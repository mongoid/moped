before do
  session[:people].find.remove_all
end

after do
  session[:people].find.remove_all
end

# CASES #

profile "Insert 1,000 documents serially (no safe mode)" do
  1_000.times do
    session[:people].insert({})
  end
end

profile "Insert 10,000 documents serially (no safe mode)" do
  10_000.times do
    session[:people].insert({})
  end
end

profile "Insert 10,000 documents serially (safe mode)" do
  session.with(safe: true) do
    10_000.times do
      session[:people].insert({})
    end
  end
end

profile "Query 1,000 normal documents (100 times)" do
  session[:people].insert(1000.times.map do
    { _id: Moped::BSON::ObjectId.new,
      name: "John",
      created_at: Time.now,
      comment: "a"*200 }
  end)
  100.times do
    session[:people].find.each { |doc| }
  end
end

profile "Query 1,000 large documents (100 times)" do
  session[:people].insert(1000.times.map { { name: "John", data: "a"*10000 }})
  100.times do
    session[:people].find.each { |doc| }
  end
end
