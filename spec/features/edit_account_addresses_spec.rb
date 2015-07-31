require 'spec_helper'

describe "User editing addresses for his account" do
  include_context "support helper"
  include_context "user with address"

  before(:each) do
    visit spree.root_path
    click_link "Login"
    sign_in!(user)
    click_link "My Account"
  end

  it "should see list of addresses saved for account" do
    page.should have_content("Addresses")
    page.should have_selector("#user_addresses > tbody > tr", :count => user.addresses.count)
  end

  it "should be able to add address" do

  it "should be able to add address" do
    expect {
      click_link I18n.t(:add_new_shipping_address, :scope => :address_book)
      fill_in Spree.t(:first_name), with: 'First'
      fill_in Spree.t(:last_name), with: 'Last'
      fill_in Spree.t(:address1), with: '123 Fake'
      fill_in Spree.t(:city), with: 'Somewhere'
      fill_in Spree.t(:zipcode), with: '12345'
      fill_in Spree.t(:phone), with: '555-555-5555'
      click_button 'Save'
    }.to change{user.addresses.count}.by(1)
  end

  pending 'adding an existing address should not create a new address object'

  it "should be able to edit address", :js => true do
    page.evaluate_script('window.confirm = function() { return true; }')
    within("#user_addresses > tbody > tr:first-child") do
      click_link Spree.t(:edit)
    end
    current_path.should == spree.edit_address_path(address)

    new_street = Faker::Address.street_address
    fill_in Spree.t(:address1), :with => new_street
    click_button "Update"
    current_path.should == spree.account_path
    page.should have_content(Spree.t(:successfully_updated, :resource => Spree.t(:address1)))

    within("#user_addresses > tbody > tr:first-child") do
      page.should have_content(new_street)
    end
  end

  it "should be able to remove address", :js => true do
    # bypass confirm dialog
    page.evaluate_script('window.confirm = function() { return true; }')
    within("#user_addresses > tbody > tr:first-child") do
      click_link Spree.t(:remove)
    end
    current_path.should == spree.account_path

    # flash message
    page.should have_content("removed")

    # header still exists for the area - even if it is blank
    page.should have_content("Addresses")

    # table is not displayed unless addresses are available
    page.should_not have_selector("#user_addresses")
  end
end
