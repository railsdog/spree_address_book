require 'spec_helper'

describe Spree::Order do
  let(:order) { FactoryGirl.create(:order) }
  let(:address) { FactoryGirl.create(:address, :user => order.user) }

  describe 'mass attribute assignment for bill_address_id, ship_address_id' do
    it 'should be able to mass assign bill_address_id' do
      params = { :bill_address_id => address.id }
      order.update_attributes(params)
      order.bill_address_id.should eq(address.id)
    end

    it 'should be able to mass assign ship_address_id' do
      params = { :ship_address_id => address.id }
      order.update_attributes(params)
      order.ship_address_id.should eq(address.id)
    end
  end

  describe "Create order with the same bill & ship addresses" do
    it "should have equal ids when set ids" do
      address = FactoryGirl.create(:address)
      @order = FactoryGirl.create(:order, :bill_address_id => address.id, :ship_address_id => address.id)
      @order.bill_address_id.should == @order.ship_address_id
    end

    it "should have equal ids when option use_billing is active" do
      address = FactoryGirl.create(:address)
      @order  = FactoryGirl.create(:order, :use_billing => true,
                        :bill_address_id => address.id,
                        :ship_address_id => nil)
      @order = @order.reload
      @order.bill_address_id.should == @order.ship_address_id
    end
  end

  describe 'default addresses should be references' do
    let(:user) { create :user_with_addreses }
    let(:order) { create :order, user: user, bill_address: nil, ship_address: nil }

    it 'should reference address instead of copy' do
      expect( order.bill_address_id ).to be_nil
      expect( order.ship_address_id ).to be_nil

      order.assign_default_addresses!

      expect( order.bill_address_id ).to eq user.bill_address_id
      expect( order.ship_address_id ).to eq user.ship_address_id
    end
  end
end
