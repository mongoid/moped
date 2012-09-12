source :rubygems

platforms :ruby do
  group :development do
    gem "perftools.rb"
    gem "rdiscount"
    gem "simplecov", require: false
    gem "yard"
  end
end

group :test do
  gem "rspec", "~> 2.11"
  unless ENV["CI"]
    gem "guard-rspec"
    gem "rb-fsevent"
  end
end

gem "rake"
gem "jruby-openssl", :platform => :jruby

gemspec
