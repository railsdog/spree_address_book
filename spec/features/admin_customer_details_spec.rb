require 'spec_helper'

feature 'Order customer details page' do
  let(:user) { create(:user) }
  let(:incomplete_order) { create(:order_with_line_items, user: user) }
  let(:guest_order) { create(:order_with_line_items, user: nil, email: 'guest@example.com') }
  let(:shipped_order) { create(:shipped_order, user: user) }

  [ :shipped_order, :guest_order, :incomplete_order ].each do |otype|
    context "With a/an #{otype.to_s.gsub('_', ' ')}" do
      scenario 'does not show the old billing address form' do
        visit spree.admin_order_customer_path(send otype)
        expect(page).to have_no_css('[data-hook="bill_address_wrapper"]')
      end

      scenario 'does not show the old shipping address form' do
        visit spree.admin_order_customer_path(send otype)
        expect(page).to have_no_css('[data-hook="ship_address_wrapper"]')
      end
    end
  end
end
