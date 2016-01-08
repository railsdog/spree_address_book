Spree Address Management
========================

This gem is a fork of
[spree_address_book](https://github.com/romul/spree_address_book).  This fork
adds significant new features, including:

- Awesome admin UI for editing and assigning addresses on orders and users
- Improved address selection UI during checkout
- Improved address editing on the user account page
- Address deduplication to help prevent a proliferation of addresses
- Lots and lots of tests (though there are still no doubt dark corners in the code)


This gem still uses the `address_book` name for translations and
`Spree::AddressBook::Config` for preferences, to make it easier to migrate from
a site using spree\_address\_book.

It is strongly recommended that you add indexes to your `spree_users` and
`spree_orders` tables on the `bill_address_id` and `ship_address_id` columns.



Testing
=======

- Run `bundle install`
- Run `apt-get install phantomjs` (or perhaps `brew install phantomjs` for Mac)
- Run `bundle exec rake test_app`
- Run `bundle exec rake` or `bundle exec rspec`


Installation
============

- Add Spree Address Management to your Gemfile:
  ```ruby
  gem 'spree_address_management', git: 'git@github.com/deseretbook/spree_address_management.git'
  ```

- Run the gem's generator (untested):
  ```bash
  bundle install
  rails g spree_address_management:install
  ```


Spree Address Book -- Copyright (c) 2011-2012 Roman Smirnov, released under the New BSD License

Spree Address Management -- Copyright (C) 2015 Deseret Book and contributors, released under the New BSD License
