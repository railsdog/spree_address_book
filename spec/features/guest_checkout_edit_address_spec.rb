# Tests to make sure an aborted guest checkout (which due to a bug in
# spree_auth_devise creates invalid nil addresses in the database) doesn't
# prevent a customer from checking out.
require 'spec_helper'

feature 'Guest order address editing', js: true do
  include_context 'checkout with product'

  let(:user) { create(:user) }

  scenario 'guest editing saved address during checkout' do
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
      within '#shipping' do
        fill_in_address(build(:fake_address))
      end

      within '#billing' do
        fill_in_address(build(:fake_address))
      end

      find('#order_use_billing').click
      click_button 'Continue'
    }.to change{ Spree::Address.count }.by(1)

    visit spree.checkout_state_path('address')
    expect(current_path).to eq(spree.checkout_state_path('address'))
    
    within '#billing' do
      click_link "Edit"
    end

    expect(current_path).to eq(spree.edit_address_path(Spree::Order.last.bill_address_id))
    new_name = Faker::Name.name
    fill_in Spree.t(:first_name), :with => new_name
    click_button "Update"
    current_path.should == spree.checkout_state_path('address')
    within("h1") { page.should have_content("Checkout") }
    
    within("#billing") do
      expect(page).to have_content(new_name)
    end

    complete_checkout

    expect(Spree::Order.last.state).to eq('complete')
  end
end

