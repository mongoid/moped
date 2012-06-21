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

profile "Insert and find one (1000x, 1 thread)" do
  1000.times do
    session[:people].insert(name: "John")
    session[:people].find.one
  end
end

profile "Insert and find one (1000x, 2 threads)" do
  2.times.map do
    Thread.new do
      session.new do |session|
        1000.times do
          session[:people].insert(name: "John")
          session[:people].find.one
        end
      end
    end
  end.each &:join
end

profile "Insert and find one (1000x, 5 threads)" do
  5.times.map do |i|
    Thread.new do
      session.new do |session|
        1000.times do
          session[:people].insert(name: "John")
          session[:people].find.one
        end
      end
    end
  end.each &:join
end

profile "Ask for all collection names, 1000x" do
  1_000.times do
    session.collection_names
  end
end
