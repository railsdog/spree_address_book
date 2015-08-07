# Configure Rails Environment
ENV["RAILS_ENV"] ||= "test"

begin
  require File.expand_path("../dummy/config/environment", __FILE__)
rescue LoadError
  puts "Could not load dummy application. Please ensure you have run `bundle exec rake test_app`"
  exit
end

require 'spree'
require 'rspec/rails'
require 'database_cleaner'
require 'ffaker'
require 'capybara/rspec'
require 'capybara/rails'
require 'capybara/poltergeist'
require 'shoulda-matchers'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.join(File.dirname(__FILE__), "support/**/*.rb")].each {|f| require f }
Dir[File.join(File.dirname(__FILE__), "factories/**/*.rb")].each {|f| require f }


# Requires factories defined in spree_core
require 'spree/testing_support/factories'

require 'spree/testing_support/controller_requests'
require 'spree/testing_support/authorization_helpers'
require 'spree/testing_support/url_helpers'
require 'spree/testing_support/preferences'
require 'spree/testing_support/capybara_ext'
require "spree/testing_support/i18n"
require 'spree/testing_support/flash'
require 'spree/testing_support/order_walkthrough'
require 'spree/testing_support/caching'
require 'paperclip/matchers'

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, { js_errors: true })
end

Capybara.javascript_driver = :poltergeist
# Capybara.default_wait_time = 20

RSpec.configure do |config|
  # Hide RSpec 3 deprecation warning
  config.infer_spec_type_from_file_location!

  config.color = true
  config.mock_with :rspec

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, comment the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = false

  # config.infer_spec_type_from_file_location!
  # config.infer_base_class_for_anonymous_controllers = false

  # enable focus
  config.run_all_when_everything_filtered = true
  config.filter_run :focus => true

  config.include FactoryGirl::Syntax::Methods
  config.include Spree::TestingSupport::Preferences
  config.include Spree::TestingSupport::UrlHelpers
  config.include Spree::TestingSupport::ControllerRequests
  config.include Spree::TestingSupport::AuthorizationHelpers
  config.include Spree::TestingSupport::Flash
  config.include Paperclip::Shoulda::Matchers
  # config.include Capybara::DSL

  config.before(:suite) do
    Capybara.match = :prefer_exact
    DatabaseCleaner.clean_with :truncation
  end

  config.before(:each) do

    @routes = Spree::AddressBook::Engine.routes

    if RSpec.current_example.metadata[:js]
      DatabaseCleaner.strategy = :truncation, {
        :except => [
          'spree_countries',
          'spree_zones',
          'spree_zone_members',
          'spree_states',
          'spree_roles'
        ]
      }
    else
      DatabaseCleaner.strategy = :transaction
    end

    # TODO: Find out why open_transactions ever gets below 0
    # See issue #3428
    if ActiveRecord::Base.connection.open_transactions < 0
      ActiveRecord::Base.connection.increment_open_transactions
    end

    DatabaseCleaner.start
    reset_spree_preferences

    Spree::Config[:company] = true # Test with the company field visible
  end

  config.after(:each) do
    # Ensure js requests finish processing before advancing to the next test
    wait_longer_for_ajax if RSpec.current_example.metadata[:js]
    DatabaseCleaner.clean
  end

  config.after(:each, :type => :feature) do |example|
    missing_translations = page.body.scan(/translation missing: #{I18n.locale}\.(.*?)[\s<\"&]/)
    if missing_translations.any?
      #binding.pry
      puts "Found missing translations: #{missing_translations.inspect}"
      puts "In spec: #{example.location}"
    end
  end

  config.fail_fast = ENV['FAIL_FAST'] || false
end


# XXX
def uaddrcount(user, str=nil)
  user = Spree::User.find(user.id) if user
  puts "\e[1;30m-->U#{user.try(:id).inspect} has #{user.reload.addresses.reload.count rescue 0} addrs (#{user.try :address_ids}) at \e[0;1m#{str}\e[0;36m #{caller(1)[0][/dbook.*/]}\e[0m\n" rescue (puts $!, *caller; raise 'foo')
end

# XXX - Compares every address to every other address, showing which are the
# same.
def addrmatrix(*addresses)
  list = addresses.flatten.uniq

  list.each do |a|
    list.each do |b|
      mismatched_attrs = []
      b_attrs = b.comparison_attributes
      a.comparison_attributes.each do |k, v|
        if v != b_attrs[k]
          mismatched_attrs << "#{k.inspect}: #{a.id}:#{v.inspect} != #{b.id}:#{b[k].inspect}"
        end
      end

      puts "#{'%03d' % a.id} -> #{'%03d' % b.id} \e[1m#{a.same_as?(b) ? 'same' : 'diff'}\e[0m U#{a.user_id.inspect}\t#{mismatched_attrs.join(', ')}"
    end
  end
end
