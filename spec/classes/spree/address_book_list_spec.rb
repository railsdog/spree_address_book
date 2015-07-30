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
    it 'receives delegated calls to #count' do
      l = Spree::AddressBookList.new(order, user)
      expect(l.count).to eq(l.addresses.count)
    end

    it 'receives delegated calls to #[]' do
      l = Spree::AddressBookList.new(order, user)
      expect(l[0]).to eq(l.addresses[0])
    end

    context 'without duplicate addresses' do
      it 'returns one address for an order with one address in both slots' do
        order.update_columns(bill_address_id: order.ship_address_id)
        expect(order.bill_address.id).to eq(order.ship_address.id)
        l = Spree::AddressBookList.new(order)
        expect(l.count).to eq(1)
      end

      it 'returns two addresses for an order with two addresses' do
        l = Spree::AddressBookList.new(order)
        expect(l.count).to eq(2)
      end

      it 'returns three addresses for a user with three addresses' do
        create(:address, user: user)
        l = Spree::AddressBookList.new(user)
        expect(l.count).to eq(3)
      end

      it 'returns four addresses for a user and order with unique addresses' do
        l = Spree::AddressBookList.new(user, order)
        expect(l.count).to eq(4)
      end
    end

    context 'with duplicate user addresses' do
      it 'returns two addresses for a user with three addresses, one duplicate' do
        user.bill_address.clone.save!
        expect(user.addresses.count).to eq(3)

        l = Spree::AddressBookList.new(user)
        expect(l.count).to eq(2)
      end

      it 'returns four addresses for a three-address (1-dup) user with a two-address order' do
        user.bill_address.clone.save!

        l = Spree::AddressBookList.new(order, user)
        expect(l.count).to eq(4)
      end
    end

    context 'with duplicate order addresses' do
      before(:each) do
        order.update_attributes!(bill_address: order.ship_address.clone)
      end

      it 'returns one address group for an order with two identical addresses' do
        l = Spree::AddressBookList.new(order)
        expect(l.count).to eq(1)
        expect(l.first.addresses.count).to be > 1
      end

      it 'returns three addresses (one group) for a duplicate-address order and a two-address user' do
        l = Spree::AddressBookList.new(user, order)
        expect(l.count).to eq(3)
        expect(l.count{|a| a.addresses.count > 1 }).to eq(1)
      end
    end

    context 'with shared user/order addresses' do
      it 'returns three addresses for a two-address order and user with one shared address' do
        user.ship_address.update_attributes!(order.bill_address.comparison_attributes.except('user_id'))

        l = Spree::AddressBookList.new(order, user)
        expect(l.count).to eq(3)

        group = l.addresses.detect{|a| a.addresses.count > 1 }
        expect(group.count).to eq(2)
        expect(group.user_ship.id).to eq(user.ship_address.id)
        expect(group.order_bill.id).to eq(order.bill_address.id)
      end

      it 'returns two addresses for an order and user with two shared addresses' do
        user.ship_address.update_attributes!(order.ship_address.comparison_attributes.except('user_id'))
        user.bill_address.update_attributes!(order.bill_address.comparison_attributes.except('user_id'))

        l = Spree::AddressBookList.new(order, user)
        expect(l.count).to eq(2)
        expect(l.addresses.all?{|a| a.addresses.count > 1 }).to eq(true)
      end
    end

    context 'with duplicate and shared addresses' do
      it 'returns five addresses for two-address order, one shared, with user with a duplicate address' do
        # One shared address
        a = order.bill_address.clone
        a.save!
        a.update_attributes!(user: user)

        # One unshared, unassigned address
        a = create(:address, user: user)

        # One duplicate address
        a = a.clone
        a.save!

        l = Spree::AddressBookList.new(order, user)
        expect(l.count).to eq(5)
        expect(l.count{|a| a.addresses.count > 1 }).to eq(2)
      end

      it 'returns the correct count for a same-address order, two shared, with a user with many duplicates' do
        # Order has duplicate addresses (minus 1)
        order.update_attributes!(ship_address: order.bill_address.clone)

        order.ship_address.update_columns(updated_at: Time.at(0))
        order.bill_address.update_columns(updated_at: Time.at(0))

        # Order addresses are both shared with the user (minus 2)
        create(:address, order.bill_address.comparison_attributes.merge('user_id' => user.id, 'updated_at' => Time.at(0)))
        create(:address, order.ship_address.comparison_attributes.merge('user_id' => user.id, 'updated_at' => Time.at(0)))

        # User has five copies of one address (minus 4)
        a = create(:address, user: user)
        4.times do
          a.clone.save!
        end

        # User's bill and ship address are clones (minus 1)
        user.ship_address.update_attributes!(user.bill_address.comparison_attributes)

        # Final count should be (2 + 2 + 2 + 5 - 4 - 2 - 1 - 1) = 3
        l = Spree::AddressBookList.new(order, user)
        expect(l.count).to eq(3)
        expect(l.addresses.all?{|a| a.addresses.count > 1 }).to eq(true)

        # First address should be most recently updated
        expect(l.first.user_bill).to eq(user.bill_address)
        expect(l.first.user_ship).to eq(user.ship_address)

        # Last address should be least recently updated
        expect(l.last.updated_at).to eq(Time.at(0))
        expect(l.last.order_bill).to be_same_as(l.last.order_ship)
      end
    end
  end
end
