# Testing Moped

Generally, all you'll need to do to test moped is pull down the repository,
`bundle`, and run `rake`.

What follows are some additional notes for running more complete tests.

## Testing against MongoHQ

Part of Moped's test suite runs against MongoHQ. This tests the authentication
code, as well as testing against a real replica set.

If you want to run this portion of the suite, email durran (at) gmail (dot) com
for the credentials.

## Testing Networking on OS X

If you're on OS X and working with the networking code in Moped, you should
also run the tests against a travis environment. Here's how I got set up for
this:

    cd ~/code
    mkdir travis
    cd travis
    git clone https://github.com/travis-ci/travis-boxes.git
    git clone https://github.com/travis-ci/travis-cookbooks.git

    cd travis-boxes
    bundle
    thor travis:init


    cat > config/worker.yml
    ruby:
      recipes:
        - rvm
        - rvm::multi
        - sweeper
        - mongodb

    thor travis:box:build ruby

    cd ~/code/moped
    vagrant up
    vagrant ssh
    cd /vagrant
    bundle
    rake
