require 'spec_helper'

feature 'User editing addresses for their account' do
  include_context "user with address"

  before(:each) do
    visit_account user
  end

  it "should see list of addresses saved for account" do
    page.should have_content("Addresses")
    expect(user.addresses.count).not_to eq(0)
    expect_address_count(user.addresses.count)
  end

  it 'should show no addresses for a user with no addresses' do
    user.addresses.delete_all
    visit spree.account_path
    expect_address_count(0)
  end

  it 'should deduplicate addresses shown in the account list' do
    5.times do
      create(:address, user: user).clone.save!
    end

    visit spree.account_path # reload
    expect_address_count(user.addresses.count - 5)
  end

  scenario 'can create a new address', js: true do
    expect {
      create_frontend_address(
        true,
        Spree.t(:first_name) => 'First',
        Spree.t(:last_name) => 'Last',
        Spree.t(:address1) => '123 Fake',
        Spree.t(:city) => 'Somewhere',
        Spree.t(:state) => Spree::State.first.name,
        Spree.t(:zipcode) => '12345',
        Spree.t(:phone) => '555-555-5555'
      )
    }.to change{user.addresses.count}.by(1)
  end

  it 'should not create a new address when it matches an existing address', js: true do
    address = create(:address, user: user)

    expect {
      create_frontend_address(true, address)
    }.not_to change{user.addresses.count}
  end

  it "should be able to edit address", :js => true do
    new_street = Faker::Address.street_address
    edit_frontend_address(user.addresses.first, true, Spree.t(:address1) => new_street)

    within("#addresses > tbody > tr:first-child") do
      expect(page).to have_content(new_street)
    end
  end

  it 'should remove an editable address if it is altered to match an existing address' do
    address2 = address.clone
    address2.address2 = 'Unique'
    address2.save!
    expect(address2).to be_editable

    expect {
      edit_frontend_address(nil, true, Spree.t(:address2) => address.address2)
    }.to change{ user.reload.addresses.count }.by(-1)

    expect{address2.reload}.to raise_error
  end

  it 'should remove the user from a non-editable address if it is edited to match an existing address', js: true do
    # There should never be a completed order with a user address, but test it
    # anyway in case the store has old orders with misassigned addresses.

    address2 = address.clone
    address2.address2 = 'Unique'
    address2.save!

    o = create(:shipped_order)
    o.update_columns(bill_address_id: address2.id, ship_address_id: address2.id)

    expect(address2).not_to be_editable

    visit spree.account_path
    expect_address_count(2)

    expect {
      edit_frontend_address(address2, true, address)
    }.to change{ user.addresses.count }.by(-1)

    expect(address2.reload.user_id).to be_nil
  end

  it "should be able to remove address", :js => true do
    expect{
      remove_frontend_address(address, true)
    }.to change{ user.addresses.count }.by(-1)

    # header still exists for the area - even if it is blank
    page.should have_content("Addresses")

    # table is not displayed unless addresses are available
    page.should_not have_selector("#addresses")
  end

  it 'updates orders with deduplicated addresses', js: true do
    user.addresses.delete_all

    a = create(:address, user: user)
    5.times do
      b = a.clone.save!
    end

    primary = Spree::AddressBookList.new(user.reload).find(a).primary_address.id
    expect(primary).not_to eq(a.id)

    order = strip_order_address_users(create(:order_with_line_items, user: user))
    order.update_columns(bill_address_id: a.id, ship_address_id: a.id)

    expect(user.addresses.count).to eq(6)

    visit spree.account_path
    expect_address_count(1)

    edit_frontend_address(primary, true, Spree.t(:first_name) => 'First')

    expect(order.reload.bill_address_id).to eq(primary)
    expect(order.ship_address_id).to eq(primary)

    expect(user.addresses.count).to eq(1)
  end
end
