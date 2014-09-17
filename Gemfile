source "http://rubygems.org"

group :test do
  gem "popen4"
  gem "rspec", "~> 2.13"
  unless ENV["CI"]
    gem "guard-rspec"
    gem "rb-fsevent"
  end
end

gem "rake"
gem "jruby-openssl", :platform => :jruby

gemspec
