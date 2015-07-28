require 'spec_helper'

feature 'Admin UI address management' do
  stub_authorization!

  let(:user) { create(:user) }
  let(:order) { create(:order_with_line_items, user: user) }
  let(:completed_order) { create(:completed_order_with_pending_payment, user: user) }
  let(:shipped_order) { create(:shipped_order, user: user) }
  let(:guest_order) {
    o = create(:order_with_line_items)
    o.update_attributes!(user: nil)
    o
  }


  describe 'User account address list' do
    scenario 'lists no addresses for a user with no addresses' do
      visit_user_addresses user
      expect_address_count 0
      expect_selected(nil, :user, :bill)
      expect_selected(nil, :user, :ship)
    end

    scenario 'lists one unselected address for a user with one address' do
      create(:address, user: user)

      visit_user_addresses user
      expect_address_count 1
      expect_selected(nil, :user, :bill)
      expect_selected(nil, :user, :ship)
    end

    scenario 'lists two unselected addresses for a user with two unique addresses' do
      a1 = create(:address, user: user)
      a2 = create(:address, user: user)

      expect(a1.same_as?(a2)).to eq(false)

      visit_user_addresses user
      expect_address_count 2
      expect_selected(nil, :user, :bill)
      expect_selected(nil, :user, :ship)
    end

    scenario 'lists and selects addresses for a user with default addresses' do
      user.update_attributes!(
        bill_address: create(:address, user: user),
        ship_address: create(:address, user: user)
      )

      visit_user_addresses user
      expect_address_count 2
      expect_selected(user.bill_address, :user, :bill)
      expect_selected(user.ship_address, :user, :ship)
    end

    scenario 'lists many addresses for a user with many addresses' do
      10.times do
        create(:address, user: user)
      end

      visit_user_addresses user
      expect_address_count 10
    end

    scenario 'does not show addresses of one order in user address list' do
      visit_order_addresses completed_order
      visit_user_addresses user
      expect_address_count 0
    end

    scenario 'does not show addresses of many orders in user address list' do
      5.times do
        create(:order, user: user)
        create(:order_with_line_items, user: user)
        create(:completed_order_with_pending_payment, user: user)
        create(:shipped_order, user: user)
      end

      expect(user.orders.count).to eq(20)

      visit_user_addresses(user)
      expect_address_count 0
    end

    scenario 'shows only two columns for default address selection' do
      create(:address, user: user)

      visit_user_addresses user

      expect(page.all('#addresses thead tr:first-child th').count).to eq(4)
    end
  end


  describe 'Order address list' do
    context 'with a guest order' do
      # TODO: Maybe force guest orders to use the Customer Details page instead of the Addresses page

      scenario 'shows only two columns for guest order address selection' do
        expect(guest_order.user).to be_nil

        visit_order_addresses(guest_order)
        expect(page.all('#addresses thead tr:first-child th').count).to eq(4)
      end

      scenario 'lists no addresses for a guest order with no addresses' do
        guest_order.update_attributes!(bill_address: nil, ship_address: nil)

        visit_order_addresses(guest_order)
        expect_address_count 0
      end

      scenario 'lists one address for a guest order with only one address' do
        guest_order.update_attributes!(ship_address: nil)

        visit_order_addresses(guest_order)
        expect_address_count 1

        guest_order.update_attributes!(ship_address: guest_order.bill_address, bill_address: nil)

        visit_order_addresses(guest_order)
        expect_address_count 1
      end

      scenario 'lists two addresses for a guest order with two addresses' do
        visit_order_addresses(guest_order)
        expect_address_count 2
      end
    end

    context 'with a logged-in order' do
      scenario 'shows four columns for logged-in user order address selection' do
        visit_order_addresses(order)
        expect(page.all('#addresses thead tr:first-child th').count).to eq(6)
      end

      scenario 'does not show addresses from other orders' do
        order
        completed_order
        shipped_order

        visit_order_addresses(order)
        expect_address_count 2

        visit_order_addresses(completed_order)
        expect_address_count 2

        visit_order_addresses(shipped_order)
        expect_address_count 2
      end

      context 'with no user addresses' do
        scenario 'lists no addresses for an order with no addresses' do
          order.update_attributes!(bill_address: nil, ship_address: nil)

          visit_order_addresses(order)
          expect_address_count 0
        end

        scenario 'lists one address for an order with only one address' do
          order.update_attributes!(ship_address: nil)

          visit_order_addresses(order)
          expect_address_count 1

          order.update_attributes!(ship_address: order.bill_address, bill_address: nil)

          visit_order_addresses(order)
          expect_address_count 1
        end

        scenario 'lists two addresses for an order with two addresses' do
          visit_order_addresses(order)
          expect_address_count 2
        end
      end

      context 'with one or more user addresses' do
        scenario 'lists one address for an order with no addresses and one user address' do
          user.update_attributes!(bill_address: create(:address, user: user))
          order.update_attributes!(bill_address: nil, ship_address: nil)

          visit_order_addresses(order)
          expect_address_count 1
        end

        scenario 'lists correct number of addresses for user with many addresses and no order addresses' do
          order.update_attributes!(bill_address: nil, ship_address: nil)

          5.times do |t|
            create(:address, user: user)
            visit_order_addresses(order)
            expect_address_count(t + 1)
          end
        end

        scenario 'lists correct number of addresses for user with many addresses with order addresses' do
          bill = order.bill_address

          5.times do |t|
            a = create(:address, user: user)
            user.update_attributes!(ship_address: a) if t == 2
            user.update_attributes!(bill_address: a) if t == 3

            order.update_attributes!(bill_address: nil)
            visit_order_addresses(order)
            expect_address_count(t + 2)

            order.update_attributes!(bill_address: bill)
            visit_order_addresses(order)
            expect_address_count(t + 3)
          end
        end
      end
    end
  end
end
