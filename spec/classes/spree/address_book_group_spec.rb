require 'spec_helper'

describe Spree::AddressBookGroup do
  describe '#initialize' do
    it 'can create an empty address group' do
      g = Spree::AddressBookGroup.new([])
      
      expect(g.addresses).to be_empty
      expect(g.user_addresses).to be_empty
      expect(g.order_addresses).to be_empty
      expect(g.user_bill).to be_nil
      expect(g.user_ship).to be_nil
      expect(g.order_bill).to be_nil
      expect(g.order_ship).to be_nil
      expect(g.primary_address).to be_nil
    end
  end
end
