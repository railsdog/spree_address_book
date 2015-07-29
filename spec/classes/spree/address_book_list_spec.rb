require 'spec_helper'

describe Spree::AddressBookList do
  let(:user) {
    u = create(:user)
    u.update_attributes!(
      ship_address: create(:address, user: u),
      bill_address: create(:address, user: u)
    )
    u
  }
  let(:order) { create(:order_with_line_items, user: user) }

  describe '#initialize' do
    it 'fails if no user or order was given' do
      expect{Spree::AddressBookList.new(nil)}.to raise_error(/given/)
    end

    it 'accepts user and order in any order' do
      a = Spree::AddressBookList.new(user, order)
      b = Spree::AddressBookList.new(order, user)

      expect(a.user).to eq(b.user)
      expect(a.order).to eq(b.order)
      expect(a.addresses).to eq(b.addresses)
    end
  end

  describe '#addresses' do
    context 'without duplicate addresses' do
      it 'returns two addresses for an order with two addresses' do
        l = Spree::AddressBookList.new(order)
        expect(l.addresses.count).to eq(2)
      end

      it 'returns three addresses for a user with three addresses' do
        create(:address, user: user)
        l = Spree::AddressBookList.new(user)
        expect(l.addresses.count).to eq(3)
      end

      it 'returns four addresses for a user and order with unique addresses' do
        l = Spree::AddressBookList.new(user, order)
        expect(l.addresses.count).to eq(4)
      end
    end

    context 'with duplicate user addresses' do
      pending
    end

    context 'with duplicate order addresses' do
      pending
    end

    context 'with shared user/order addresses' do
      pending
    end

    context 'with duplicate and shared addresses' do
      pending
    end
  end
end
