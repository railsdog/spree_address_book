require 'spec_helper'

feature 'Admin UI address editing' do
  stub_authorization!

  let(:user) { create(:user) }
  let(:order) { strip_order_address_users(create(:order_with_line_items, user: user)) }
  let(:completed_order) { create(:completed_order_with_pending_payment, user: user) }
  let(:shipped_order) { create(:shipped_order, user: user) }
  let(:guest_order) { strip_order_address_users(create(:order_with_line_items, user: nil, email: 'guest@example.com')) }

  describe 'User account address list' do
    scenario 'can edit a single address' do
      a = create(:address, user: user)

      expect {
        edit_address(
          user,
          a.id,
          true,
          Spree.t(:street_address_2) => 'new_address_two'
        )
      }.not_to change{user.reload.addresses.count}

      expect(a.reload.address2).to eq('new_address_two')
      expect(user.addresses.last.id).to eq(a.id)
      expect(a.deleted_at).to be_nil
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

      pending
    end
  end


  describe 'Order address list' do
    context 'with a guest order' do
      context 'with only one address' do
        before(:each) do
          guest_order.update_attributes!(ship_address: nil)
        end

        it 'cannot edit a different address not from the order' do
          pending
        end

        it 'can edit the order address' do
          a = build(
            :address,
            first_name: 'First',
            last_name: 'Last',
            company: 'Company',
            address1: '123 Fake',
            address2: 'Floor Three',
            city: 'Beverly Hills',
            phone: '555-555-5555',
            alternative_phone: '555-555-5556'
          )

          expect(a).to be_valid

          orig_id = guest_order.bill_address_id

          expect {
            edit_address(
              guest_order,
              guest_order.bill_address,
              true,
              a
            )
          }.not_to change{ Spree::Address.count }

          expect(guest_order.reload.bill_address_id).to eq(orig_id)
          expect(guest_order.bill_address).to be_same_as(a)
          expect(guest_order.ship_address).to be_nil
        end
      end

      pending
    end

    context 'with a logged-in order' do
      context 'with no user addresses' do
        pending
      end

      context 'with one or more user addresses' do
        pending
      end
    end

    context 'with duplicate addresses' do
      pending
    end
  end
end
