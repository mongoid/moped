source "https://rubygems.org"

group :test do
  gem "rspec", "~> 2.11"
  unless ENV["CI"]
    gem "guard-rspec"
    gem "rb-fsevent"
  end
end

gem "bson", github: "mongodb/bson-ruby"

gem "rake"
gem "jruby-openssl", :platform => :jruby

gemspec
