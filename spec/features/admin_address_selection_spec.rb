require 'spec_helper'

feature 'Admin UI address management' do
  stub_authorization!

  let(:user) { create(:user) }
  let(:order) { create(:order_with_line_items) }

  describe 'User account address list' do
    scenario 'lists no addresses for a user with no addresses' do
      visit_user_addresses user
      expect_address_count 0
    end

    scenario 'lists one address for a user with one address' do
      create(:address, user: user)

      visit_user_addresses user
      expect_address_count 1
    end

    scenario 'lists two addresses for a user with two unique addresses' do
      a1 = create(:address, user: user)
      a2 = create(:address, user: user)

      expect(a1.same_as?(a2)).to eq(false)

      visit_user_addresses user
      expect_address_count 2
    end

    scenario 'lists many addresses for a user with many addresses' do
      10.times do
        create(:address, user: user)
      end

      visit_user_addresses user
      expect_address_count 10
    end

    scenario 'shows only two columns for default address selection' do
      create(:address, user: user)

      visit_user_addresses user

      expect(page.all('#addresses thead tr:first-child th').count).to eq(4)
    end
  end
end
