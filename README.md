SpreeAddressBook
================

This extension allows users select `bill_address` and `ship_address` from addresses, which was already entered by current user.


Testing
=======

- Run `bundle install`
- Run `bundle exec rake test_app`
- Run `apt-get install phantomjs` (or perhaps `brew install phantomjs` for Mac)
- Run `bundle exec rake` or `bundle exec rspec`


Installation
============

      Add `gem "spree_address_book", :git => "git://github.com/romul/spree_address_book.git"
      Run `bundle install`
      Run `rails g spree_address_book:install`


Copyright (c) 2011-2015 Roman Smirnov and contributors, released under the New BSD License
