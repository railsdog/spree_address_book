require 'spec_helper'

describe 'Admin UI address management' do
  stub_authorization!

  let(:user) { create(:user) }

  describe 'User account address list' do
    it 'lists no addresses for a user with no addresses' do
      visit spree.admin_addresses_path(user_id: user.id)
      expect(page).to have_content(Spree.t(:addresses, :scope => 'admin.user'))
    end
  end
end
