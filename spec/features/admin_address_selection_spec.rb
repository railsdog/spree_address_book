require 'spec_helper'

feature 'Admin UI address selection' do
  stub_authorization!

  let(:user) { create(:user) }
  let(:order) { strip_order_address_users(create(:order_with_line_items, user: user)) }
  let(:completed_order) { create(:completed_order_with_pending_payment, user: user) }
  let(:shipped_order) { create(:shipped_order, user: user) }
  let(:guest_order) { strip_order_address_users(create(:order_with_line_items, user: nil, email: 'guest@example.com')) }

  scenario 'redirects back to the main admin page if no order or user were found' do
    visit spree.admin_addresses_path
    expect(page).to have_content(Spree.t(:no_resource_found, resource: 'order or user'))
    expect(current_path).to eq('/admin')
  end

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
        strip_order_address_users(create(:order, user: user))
        strip_order_address_users(create(:order_with_line_items, user: user))
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

    context 'with duplicate addresses' do
      before(:each) do
        user.update_attributes!(
          ship_address: create(:address, user: user),
          bill_address: create(:address, user: user)
        )

        # Set up duplicate addresses
        3.times do
          a = create(:address, user: user)
          a.clone.save!
        end
      end

      scenario 'shows the correct number of addresses when addresses are duplicated but bill/ship are unique' do
        expect(user.bill_address).not_to be_same_as(user.ship_address)
        expect(user.ship_address).not_to be_same_as(user.bill_address)
        expect(user.addresses.count).to eq(8)

        visit_user_addresses user
        expect_address_count 5
      end

      scenario 'shows the correct number of addresses when bill/ship are the same address' do
        user.ship_address.delete
        user.update_attributes!(ship_address_id: user.bill_address_id)
        expect(user.bill_address.id).to eq(user.ship_address.id)

        visit_user_addresses user
        expect_address_count 4
      end

      scenario 'shows the correct number of addresses when bill/ship are duplicated addresses' do
        user.ship_address.delete
        user.update_attributes!(ship_address: user.bill_address.clone)
        expect(user.bill_address.id).not_to eq(user.ship_address.id)

        visit_user_addresses user
        expect_address_count 4
      end

      scenario 'shows the correct number of addresses when bill/ship are blank' do
        user.update_attributes!(bill_address_id: nil, ship_address_id: nil)
        visit_user_addresses user
        expect_address_count 5
      end
    end

    context 'with address updates disabled' do
      force_user_address_updates(false)

      scenario 'disables user address selection radio buttons' do
        user.update_attributes!(
          bill_address: create(:address, user: user),
          ship_address: create(:address, user: user)
        )

        visit_addresses user

        expect(page).to have_css(address_radio_selector(user.bill_address, :user, :bill) + '[disabled]')
        expect(page).to have_css(address_radio_selector(user.ship_address, :user, :ship) + '[disabled]')
      end

      scenario 'does not allow address creation' do
        user.addresses.delete_all

        visit_addresses user

        expect(page).to have_content(Spree.t(:no_resource_found, resource: Spree::Address.model_name.human.pluralize))
        expect(page).to have_content(Spree.t(:addresses_not_editable, resource: Spree::User.model_name.human))
        expect(page).to have_no_css('#new_address_link')
      end
    end
  end


  describe 'Order address list' do
    context 'with a guest order' do
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

      context 'with only one address' do
        before(:each) do
          guest_order.update_attributes!(ship_address: nil)
        end

        scenario 'lists one address' do
          visit_order_addresses(guest_order)
          expect_address_count 1

          guest_order.update_attributes!(ship_address: guest_order.bill_address, bill_address: nil)

          visit_order_addresses(guest_order)
          expect_address_count 1
        end

        scenario 'can assign one address to the other type' do
          visit_order_addresses(guest_order)
          select_address(guest_order.bill_address, :order, :ship)
          submit_addresses
          expect(guest_order.reload.ship_address.same_as?(guest_order.bill_address)).to eq(true)

          guest_order.update_attributes!(bill_address: nil)
          visit_order_addresses(guest_order)
          select_address(guest_order.ship_address, :order, :bill)
          submit_addresses
          expect(guest_order.reload.bill_address.same_as?(guest_order.ship_address)).to eq(true)

          # TODO: Expected IDs of addresses?  Should they be separate objects or the same?
        end
      end

      scenario 'lists two addresses for a guest order with two addresses' do
        visit_order_addresses(guest_order)
        expect_address_count 2
      end

      scenario 'can reassign addresses' do
        bill = guest_order.bill_address
        ship = guest_order.ship_address

        visit_order_addresses(guest_order)

        expect_selected(ship, :order, :ship)
        expect_selected(bill, :order, :bill)
        select_address(bill, :order, :ship)
        select_address(ship, :order, :bill)
        expect_selected(ship, :order, :bill)
        expect_selected(bill, :order, :ship)

        submit_addresses

        guest_order.reload
        expect(bill.same_as?(guest_order.ship_address)).to eq(true)
        expect(ship.same_as?(guest_order.bill_address)).to eq(true)
        expect(ship.same_as?(guest_order.ship_address)).to eq(false)

        expect_selected(bill, :order, :ship)
        expect_selected(ship, :order, :bill)
        expect(bill.id).to eq(guest_order.ship_address_id)
        expect(ship.id).to eq(guest_order.bill_address_id)
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
          order.update_columns(ship_address_id: nil)

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

        scenario 'shares selected incomplete order addresses with the user' do
          visit_order_addresses(order)

          expect(user.addresses.count).to eq(0)

          expect {
            select_address(order.bill_address, :user, :ship)
            select_address(order.ship_address, :user, :bill)
            submit_addresses
          }.not_to change{ [order.reload.bill_address_id, order.ship_address_id] }

          # Addresses should be the same object
          expect(user.reload.addresses.count).to eq(2)
          expect(order.bill_address.user_id).to eq(user.id)
          expect(order.ship_address.user_id).to eq(user.id)
          expect(order.bill_address_id).to eq(user.ship_address_id)
          expect(order.ship_address_id).to eq(user.bill_address_id)
        end

        scenario 'clones selected complete order addresses to the user' do
          visit_order_addresses(completed_order)

          expect(user.addresses.count).to eq(0)

          expect {
            select_address(completed_order.bill_address, :user, :ship)
            select_address(completed_order.ship_address, :user, :bill)
            submit_addresses
          }.not_to change{ [completed_order.reload.bill_address_id, completed_order.ship_address_id] }

          # Addresses should match but have different IDs
          expect(user.reload.addresses.count).to eq(2)
          expect(completed_order.reload.bill_address.user_id).to be_nil
          expect(completed_order.ship_address.user_id).to be_nil
          expect(completed_order.bill_address).to be_same_as(user.ship_address)
          expect(completed_order.bill_address_id).not_to eq(user.ship_address_id)
          expect(completed_order.ship_address).to be_same_as(user.bill_address)
          expect(completed_order.ship_address_id).not_to eq(user.bill_address_id)
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
            begin
              a = create(:address, user: user)
              user.update_attributes!(ship_address: a) if t == 2
              user.update_attributes!(bill_address: a) if t == 3

              order.update_columns(bill_address_id: nil)
              visit_order_addresses(order)
              expect_address_count(t + 2)

              order.update_columns(bill_address_id: bill.id)
              visit_order_addresses(order)
              expect_address_count(t + 3)
            rescue => e
              raise "#{e.message} on loop #{t}"
            end
          end
        end
      end
    end

    context 'with duplicate addresses' do
      scenario 'shows one item for an order with two identical addresses' do
        order.update_columns(bill_address_id: cloned_address_id(order.ship_address))
        expect(order.ship_address_id).not_to eq(order.bill_address_id)
        expect(order.ship_address).to be_same_as(order.bill_address)
        expect(Spree::AddressBookList.new(order).count).to eq(1)

        visit_order_addresses(order)
        expect_address_count(1)
      end

      scenario 'shows one item for a guest order with two identical addresses' do
        guest_order.update_columns(bill_address_id: cloned_address_id(guest_order.ship_address))
        expect(guest_order.ship_address_id).not_to eq(guest_order.bill_address_id)
        begin # XXX
          expect(guest_order.ship_address).to be_same_as(guest_order.bill_address)
        rescue => e
          addrmatrix(guest_order.ship_address, guest_order.bill_address) # XXX
          raise
        end
        expect(Spree::AddressBookList.new(guest_order).count).to eq(1)

        visit_order_addresses(guest_order)
        expect_address_count(1)
      end

      scenario 'shows two items for an order with identical addresses and one user address' do
        a = order.ship_address.clone
        a.user = user
        a.address2 = 'different'
        a.save!
        visit_order_addresses(order)
        expect_address_count(3)

        order.update_columns(bill_address_id: cloned_address_id(order.ship_address))
        expect(Spree::AddressBookList.new(order).count).to eq(1)
        visit_order_addresses(order)
        expect_address_count(2)
      end

      scenario 'shows two items for an order with different addresses and a user with one matching address' do
        user.bill_address = order.ship_address.clone
        user.save!

        visit_order_addresses(order)
        expect_address_count(2)
      end

      scenario 'shows two items for an order and user with matching different addresses' do
        user.update_attributes!(ship_address: order.bill_address.clone, bill_address: order.ship_address.clone)
        expect(Spree::AddressBookList.new(order, user).count).to eq(2)

        visit_order_addresses(order)
        expect_address_count(2)
      end

      scenario 'shows two items for a one-address order and two-address user with one address shared' do
        create(:address, user: user)
        order.update_columns(bill_address_id: cloned_address_id(order.ship_address))
        a = order.ship_address.clone
        a.user = user
        a.save!

        visit_order_addresses(order)
        addrmatrix(order.bill_address, order.ship_address, user.addresses) # XXX
        expect_address_count(2)
      end

      context 'with lots of case mismatched addresses' do
        before(:each) do
          4.times do
            # 8 addresses, 4 unique (testing case insensitivity)
            a = create(:address, user: user)
            b = a.clone
            a.firstname = a.firstname.downcase
            a.save!
            b.save!

            # Make sure downcased address is older, so it's not the primary_address
            expect(b.updated_at).to be > a.updated_at
          end
        end

        context 'with an incomplete order' do
          scenario 'shows expected number of items for an order and user with many duplicated/shared addresses' do
            user.update_attributes!(bill_address: user.addresses.first, ship_address: order.ship_address.clone)
            expect(user.ship_address.user).to eq(user)

            # User should have five unique addresses, the order two, with one shared, for six total.
            visit_order_addresses(order)
            expect_address_count(6)

            # Check again with a duplicated order address
            order.bill_address.update_attributes!(order.ship_address.comparison_attributes.except('user_id'))
            visit_order_addresses(order)
            expect_address_count(5)
          end

          scenario 'assigns the primary deduplicated address when selecting addresses' do
            l = Spree::AddressBookList.new(order, user)
            a = l.find(user.addresses[5])

            select_addresses(
              order,
              user_bill: a.primary_address,
              user_ship: a.primary_address,
              order_bill: a.primary_address,
              order_ship: a.primary_address
            )

            expect(order.reload.bill_address).to be_same_as(a)
            expect(order.bill_address_id).to eq(a.id)
            expect(order.ship_address_id).to eq(a.id)

            expect(user.reload.bill_address_id).to eq(a.id)
            expect(user.ship_address_id).to eq(a.id)
          end
        end

        context 'with a complete order' do
          let(:order) { completed_order }

          context 'without editable addresses', js: true do
            scenario 'cannot choose order address radio buttons' do
              visit_addresses(order)

              expect(page).to have_css(address_radio_selector(order.bill_address, :order, :bill) + '[disabled]')
              expect(page).to have_css(address_radio_selector(order.ship_address, :order, :ship) + '[disabled]')

              expect{ select_address(order.bill_address, :order, :bill) }.to raise_error
            end

            scenario 'cannot submit different order addresses' do
              visit_addresses(order)

              # Re-enable the disabled order address radio buttons to test the backend controller
              page.evaluate_script('$("input + label").remove()')
              page.evaluate_script('$("input:disabled").prop("disabled", false).prop("readonly", false)')

              select_address(order.bill_address, :order, :ship)
              select_address(order.ship_address, :order, :bill)
              submit_addresses(false)
            end

            scenario 'order addresses do not have an edit link' do
              a = create(:address, user: order.user)
              visit_addresses(order)

              expect(page).to have_no_css("#edit-address-#{order.bill_address_id}")
              expect(page).to have_no_css("#edit-address-#{order.ship_address_id}")
              expect(page).to have_css("#edit-address-#{user.addresses.first.id}")
            end
          end

          context 'with editable addresses' do
            make_addresses_editable

            scenario 'assigns primary address to user, cloned addresses to order' do
              l = Spree::AddressBookList.new(order, user)
              a = l.find(user.addresses[5])

              select_addresses(
                order,
                user_bill: a.primary_address,
                user_ship: a.primary_address,
                order_bill: a.primary_address,
                order_ship: a.primary_address
              )

              expect(order.reload.bill_address).to be_same_as(a)
              expect(order.ship_address).to be_same_as(a)
              expect(order.bill_address_id).not_to eq(a.id)
              expect(order.ship_address_id).not_to eq(a.id)
              expect(order.ship_address_id).not_to eq(order.bill_address_id)

              expect(user.reload.bill_address_id).to eq(a.id)
              expect(user.ship_address_id).to eq(a.id)
            end
          end
        end
      end
    end
  end
end
