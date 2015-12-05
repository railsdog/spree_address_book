require 'spec_helper'

feature 'User account admin page' do
  let(:user) { create(:user) }

  scenario 'does not show a link to addresses' do
    visit spree.edit_admin_user_path(user)
    expect(page).to have_no_content(Spree.t(:'admin.user.addresses'))
  end
end
