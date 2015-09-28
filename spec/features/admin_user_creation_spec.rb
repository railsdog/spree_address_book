require 'spec_helper'

feature 'Admin user creation', js: true do
  stub_authorization!

  before(:each) do
    create(:state, country: create(:country))
    Spree::User.delete_all

    visit spree.admin_users_path
    click_link Spree.t(:new_user)
    expect(current_path).to eq(spree.new_admin_user_path)

    fill_in 'user[email]', with: 'test@example.com'
    fill_in 'user[password]', with: 'pass123'
    fill_in 'user[password_confirmation]', with: 'pass123'
  end

  scenario 'can create a user without a billing address' do
    click_button Spree.t(:create)

    u = Spree::User.last
    expect(current_path).to eq(spree.edit_admin_user_path(u))
    expect(u.addresses.count).to eq(0)
    expect(u.email).to eq('test@example.com')
  end

  scenario 'billing address fails validation if partially filled' do
    fill_in 'user[bill_address_attributes][firstname]', with: 'Test'
    click_button Spree.t(:create)
    expect(current_path).to eq(spree.admin_users_path)
    expect(page).to have_content(I18n.t('errors.messages.not_saved.other', count: nil, resource: 'record'))
  end

  scenario 'can create a billing address' do
    fill_in_address build(:address)
    click_button Spree.t(:create)

    u = Spree::User.last
    expect(current_path).to eq(spree.edit_admin_user_path(u))
    expect(u.addresses.count).to eq(1)
    expect(u.email).to eq('test@example.com')
    expect_user_addresses(u)
  end
end
