require 'bundler'
Bundler::GemHelper.install_tasks

require 'rspec/core/rake_task'

require 'spree/testing_support/extension_rake'

RSpec::Core::RakeTask.new

task :default => [:spec]

desc 'Generates a dummy app for testing the extension'
task :test_app do
  ENV['LIB_NAME'] = 'spree_address_book'
  Rake::Task['extension:test_app'].invoke # 'Spree::User'
end
