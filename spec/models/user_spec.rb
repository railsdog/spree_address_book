require 'spec_helper'

describe Spree::User do
  let(:user) { FactoryGirl.create(:user) }
  let(:address) { FactoryGirl.create(:address) }

  describe 'user has_many addresses' do
    let(:address2) { FactoryGirl.create(:address) }
    before {
      address.user = user
      address.save
      address2.user = user
      address2.save
    }

    it 'should have many addresses' do
      user.should respond_to(:addresses)
      user.addresses.should eq([address2, address])
    end
  end

  describe 'address link' do
    it 'should auto-link addresses' do
      expect( address.user_id ).to be_nil

      user.bill_address = address
      user.save!

      expect( address.user_id ).to eq user.id
    end
  end

  describe 'default assignment' do
    let(:order) { create :order_with_line_items, user: user }

    it 'default assignment is reference' do
      expect( user.ship_address ).to be_nil
      expect( user.bill_address ).to be_nil

      user.persist_order_address order

      expect( user.ship_address_id ).to eq order.ship_address_id
      expect( user.bill_address_id ).to eq order.bill_address_id
    end
  end

end
