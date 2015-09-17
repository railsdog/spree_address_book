require 'spec_helper'

describe Spree::Admin::AddressesController do
  stub_authorization!

  describe '#edit' do
    context 'with a guest order' do
      let(:guest_order) { strip_order_address_users(create(:order_with_line_items, user: nil, email: 'guest@example.com')) }

      it 'rejects address IDs that do not belong to the guest order' do
        a1 = create(:address)

        expect {
          spree_put :update, id: a1.id, order_id: guest_order.id, address: a1.comparison_attributes.merge('address1' => 'different')
        }.not_to change{ a1.reload.updated_at }

        expect(flash[:success]).not_to be_present
        expect(flash[:notice]).not_to be_present
        expect(flash[:error]).to be_present
      end

      it 'accepts address IDs from the guest order' do
        a1 = guest_order.bill_address

        expect {
          spree_put :update, id: a1.id, order_id: guest_order.id, address: a1.comparison_attributes.merge('address1' => 'different')
        }.to change{ a1.reload.updated_at }

        expect(flash[:success]).to be_present
        expect(flash[:error]).not_to be_present
      end
    end
  end
end
