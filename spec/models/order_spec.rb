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

  describe 'address referencing' do
    let(:user) { create :user_with_addreses }
    let(:order) do
      create(:order_with_line_items, user: user, bill_address: nil, ship_address: nil).tap do |order|
        create :payment, amount: order.total, order: order, state: 'completed'
      end
    end

    before(:each) do
      expect( order.bill_address_id ).to be_nil
      expect( order.ship_address_id ).to be_nil
      order.assign_default_addresses!
    end

    it 'should initially reference address instead of copy' do
      expect( order.bill_address_id ).to eq user.bill_address_id
      expect( order.ship_address_id ).to eq user.ship_address_id
    end

    it 'should clone addresses on complete' do
      expect( order.state ).to eq 'cart'
      until order.complete?
        result = order.next
        puts order.errors.full_messages.to_sentence unless result
        expect(result).to eq(true)
      end
      order.reload

      # One complete the order address are no longer the user addresses
      expect( order.bill_address_id ).not_to eq user.bill_address_id
      expect( order.ship_address_id ).not_to eq user.ship_address_id

      # The shipments should refer to the same object as the order does
      for shipment in order.shipments
        expect( shipment.address_id ).to eq order.ship_address_id
      end

      # Once complete the order addresses do not tie to the address book
      expect( order.bill_address.user_id ).to be_nil
      expect( order.ship_address.user_id ).to be_nil
    end
  end

end
