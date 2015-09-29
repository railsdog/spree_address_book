# Tests to make sure an aborted guest checkout (which due to a bug in
# spree_auth_devise creates invalid nil addresses in the database) doesn't
# prevent a customer from checking out.
require 'spec_helper'

feature 'Aborted guest checkout', js: true do
  include_context 'checkout with product'

  let(:user) { create(:user) }

  scenario 'does not prevent later logged-in checkout' do
    Spree::Order.delete_all
    Spree::Address.delete_all

    add_mug_to_cart
    restart_checkout
    fill_in 'order_email', with: 'guest@example.com'
    click_button 'Continue'
    click_button 'Continue'
    sign_in_to_cart!(user)
    click_button 'Continue'

    expect(current_path).to eq(spree.checkout_state_path(:address))

    expect {
      within '#billing' do
        fill_in_address(build(:fake_address))
      end

      within '#shipping' do
        fill_in_address(build(:fake_address))
      end

      complete_checkout
    }.to change{ Spree::Address.count }.by(4)

    expect(Spree::Order.last.state).to eq('complete')
  end
end
