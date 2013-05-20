source "https://rubygems.org"

group :test do
  gem "rspec", "~> 2.13"
  if ENV["CI"]
    gem "coveralls", :require => false
  else
    gem "guard-rspec"
    gem "rb-fsevent"
  end
end

gem "rake"
gem "jruby-openssl", :platform => :jruby

gemspec
