Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_address_management'
  s.version     = '2.3.6'
  s.summary     = "Allows users and admins to save and manage multiple addresses"
  s.description = "A fork of spree_address_book (https://github.com/romul/spree_address_book).  This gem allows Spree users to save multiple addresses for use during checkout, and provides robust tools for admins to assign, edit, and delete addresses."
  s.required_ruby_version = '>= 1.9.3'
  s.date        = '2015-09-16'

  s.authors            = ["Deseret Book"]
  s.email             = 'webdev@deseretbook.com'
  s.homepage          = 'https://github.com/deseretbook/spree_address_management'

  s.files        = `git ls-files`.split("\n")
  s.test_files   = `git ls-files -- spec/*`.split("\n")
  s.require_path = 'lib'
  s.requirements << 'none'

  spree_version = '~> 2.3'
  s.add_dependency 'spree_core', spree_version
  s.add_dependency 'spree_frontend', spree_version
  s.add_dependency 'spree_backend', spree_version

  s.add_development_dependency 'sass-rails', '~> 4.0.2'
  s.add_development_dependency 'coffee-rails'
  s.add_development_dependency 'rspec-rails', '~> 2.14'
  s.add_development_dependency 'shoulda-matchers', '~> 2.5'
  s.add_development_dependency 'ffaker'
  s.add_development_dependency 'factory_girl', '~> 4.5.0'
  s.add_development_dependency 'database_cleaner', '~> 1.2.0'
  s.add_development_dependency 'sqlite3', '~> 1.3.8'
  s.add_development_dependency 'capybara', '~> 2.2.1'
  s.add_development_dependency 'poltergeist'
end
