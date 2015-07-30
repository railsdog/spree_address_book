require 'spec_helper'

describe Spree::AddressBookGroup do
  let(:user) { create(:user) }
  let(:user_address) { create(:address, user: user) }
  let(:many_addresses) {
    list = [user_address]
    5.times do
      a = user_address.clone
      a.save!
      list << a
    end

    list[4].update_attributes!(user: nil)
    list[5].update_attributes!(user: nil)

    list
  }

  let(:empty_address_group) { Spree::AddressBookGroup.new([]) }

  let(:many_address_group) {
    list = many_addresses

    Spree::AddressBookGroup.new(
      list,
      user_ship: list[1],
      user_bill: list[2],
      order_ship: list[4],
      order_bill: list[5]
    )
  }

  describe '#initialize' do
    it 'can create an empty address group' do
      g = empty_address_group
      
      expect(g.addresses).to be_empty
      expect(g.user_addresses).to be_empty
      expect(g.order_addresses).to be_empty
      expect(g.user_ship).to be_nil
      expect(g.user_bill).to be_nil
      expect(g.order_ship).to be_nil
      expect(g.order_bill).to be_nil
      expect(g.primary_address).to be_nil
    end

    it 'can create an address group with several addresses' do
      g = many_address_group

      expect(g.addresses.count).to eq(6)
      expect(g.user_addresses.count).to eq(4)
      expect(g.order_addresses.count).to eq(2)
      expect(g.user_ship).to eq(many_addresses[1])
      expect(g.user_bill).to eq(many_addresses[2])
      expect(g.order_ship).to eq(many_addresses[4])
      expect(g.order_bill).to eq(many_addresses[5])
      expect(g.primary_address).to eq(many_addresses[3])
    end

    # TODO: non-happy-path tests?  Test excess userless addresses, address user reassignment
  end

  describe '#id' do
    it 'delegates to #primary_address' do
      expect(many_address_group.updated_at).to eq(many_addresses[3].updated_at)
      expect(empty_address_group.updated_at).to be_nil
    end
  end

  describe '#updated_at' do
    it 'delegates to #primary_address' do
      expect(many_address_group.updated_at).to eq(many_addresses[3].updated_at)
      expect(empty_address_group.updated_at).to be_nil
    end
  end

  describe '#to_s' do
    it 'delegates to #primary_address' do
      expect(many_address_group.to_s).to match(/br/)
      expect(empty_address_group.to_s).to be_blank
    end
  end

  describe '#same_as?' do
    it 'delegates to #primary_address' do
      expect(many_address_group).to be_same_as(many_address_group.addresses.last)
      expect(many_address_group.addresses.last).to be_same_as(many_address_group)
    end
  end
end
