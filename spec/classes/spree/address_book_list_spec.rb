require 'spec_helper'

describe Spree::AddressBookList do
  let(:user) {
    u = create(:user)
    u.update_attributes!(
      ship_address: create(:address, user: u),
      bill_address: create(:address, user: u)
    )
    u.reload
  }
  let(:order) {
    o = create(:order_with_line_items, user: user, bill_address: nil, ship_address: nil)
    o.update_columns(bill_address_id: create(:address).id, ship_address_id: create(:address).id)
    expect(o.bill_address.user).to be_nil
    expect(o.ship_address.user).to be_nil
    o
  }

  describe '#initialize' do
    it 'creates an empty list if no user or order was given' do
      expect(Spree::AddressBookList.new(nil, nil).count).to eq(0)
    end

    it 'accepts user and order in any order' do
      a = Spree::AddressBookList.new(user, order)
      b = Spree::AddressBookList.new(order, user)

      expect(a.user).to eq(b.user)
      expect(a.order).to eq(b.order)
      expect(a.addresses).to eq(b.addresses)
    end
  end

  describe '#find' do
    before(:each) do
      a = create(:address, user: user)
      4.times do
        a.clone.save!
      end

      a = order.bill_address.clone
      a.user = user
      a.save!
    end

    let(:list) { Spree::AddressBookList.new(user, order) }

    it "returns the same group for each group's primary address" do
      list.addresses.each do |a|
        expect(list.find(a)).to eq(a)
        expect(list.find(a.primary_address)).to eq(a)
      end
    end

    it 'returns the expected group for a newly constructed matching address' do
      list.addresses.each do |a|
        a = Spree::Address.new(a.primary_address.comparison_attributes.except('user_id'))
        expect(list.find(a)).to be_same_as(a)
      end
    end

    it 'returns a matching group for each address on the order and user' do
      user.addresses.flatten.each do |a|
        expect(list.find(a).primary_address).to be_same_as a
      end

      expect(list.find(user.ship_address).user_ship).to eq(user.ship_address)
      expect(list.find(user.bill_address).user_bill).to eq(user.bill_address)
      expect(list.find(order.ship_address).order_ship).to eq(order.ship_address)
      expect(list.find(order.bill_address).order_bill).to eq(order.bill_address)
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

    context 'with a completed order and unmodified factory user' do
      let(:user) { create(:user) }
      let(:completed_order) { create(:completed_order_with_pending_payment, user: user) }

      it 'returns two addresses for the order and user together' do
        expect([completed_order.bill_address_id, completed_order.ship_address_id].compact.uniq.count).to eq(2)
        expect(user.addresses.count).to eq(0)
        l = Spree::AddressBookList.new(completed_order, user)
        expect(l.count).to eq(2)
      end
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
        bill = order.ship_address.clone
        bill.save!
        order.update_columns(bill_address_id: bill.id)
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
        a.update_attributes!(user: user)

        # One unshared, unassigned address
        a = create(:address, user: user)

        # One duplicate address
        a = a.clone
        a.save!

        expect(user.reload.addresses.count).to eq(5)
        l = Spree::AddressBookList.new(order, user)
        expect(l.count).to eq(5)
        expect(l.count{|a| a.addresses.count > 1 }).to eq(2)
      end

      it 'returns the correct count for a same-address order, two shared, with a user with many duplicates' do
        # Order has duplicate addresses (minus 1)
        ship = order.bill_address.clone
        ship.save!
        order.update_columns(ship_address_id: ship.id)

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
        expect(user.reload.addresses.count).to eq(9)
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
