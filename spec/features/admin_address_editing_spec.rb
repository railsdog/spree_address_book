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

      visit_user_addresses user
      click_link "edit-address-#{a.id}"
      expect(current_path).to eq(spree.edit_admin_address_path(a))

      expect {
        fill_in Spree.t(:street_address_2), with: 'new_address_two'
        click_button Spree.t('actions.update')
        expect(path_with_query).to eq(spree.admin_addresses_path(user_id: user.id))
        expect(page).to have_content(Spree.t(:account_updated))
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

        pending
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
