module Spree
  class AddressManagementConfiguration < Preferences::Configuration
    preference :disable_bill_address, :boolean, :default => false
  end
end
