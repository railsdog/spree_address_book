require 'spree/testing_support/factories'
require 'securerandom'

FactoryGirl.define do
  # A factory with different data for every address field.
  factory :fake_address, parent: :address do
    firstname { Faker::Name.first_name }
    lastname { Faker::Name.last_name }
    company { Faker::Company.name }
    address1 { Faker::Address.street_address }
    address2 { "#{SecureRandom.uuid} #{Faker::Address.secondary_address}"[0..254] }
    city { Faker::Address.city }
    zipcode { Faker::AddressUS.zip_code }
    phone { Faker::PhoneNumber.phone_number }
    alternative_phone { Faker::PhoneNumber.phone_number if Spree::Config[:alternative_shipping_phone] }
  end
end

FactoryGirl.modify do
  # Modify the address factory to generate unique addresses.
  factory :address do
    address2 { SecureRandom.uuid }
    state { Spree::State.first || create(:state) }
  end
end
