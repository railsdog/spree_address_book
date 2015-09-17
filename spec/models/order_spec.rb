require 'spec_helper'

describe Spree::Order do
  let(:user) { create :user_with_addreses }
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

    context :deduplication do
      let(:bill) {
        a = user.bill_address.clone_without_user
        a.save!
        a
      }
      let(:ship) {
        a = user.ship_address.clone_without_user
        a.save!
        a
      }

      it 'finds an existing user address if assigned a matching copy' do
        order.update_attributes!(bill_address: bill, ship_address: ship)

        # Order should have found and used the user addresses instead
        expect(order.bill_address_id).to eq(user.bill_address_id)
        expect(order.ship_address_id).to eq(user.ship_address_id)

        # Duplicate addresses should be deleted
        expect{bill.reload}.to raise_error
        expect{ship.reload}.to raise_error
      end

      it 'does not try to find an existing user address if complete' do
        order.update_attributes!(state: 'complete')
        order.update_attributes!(bill_address: bill, ship_address: ship)

        expect(order.bill_address_id).not_to eq(user.bill_address_id)
        expect(order.ship_address_id).not_to eq(user.ship_address_id)
        expect{bill.reload}.not_to raise_error
        expect{ship.reload}.not_to raise_error
      end
    end

    it 'should clone addresses on complete' do
      expect( order.state ).to eq 'cart'
      until order.complete?
        order.next!
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

    it 'should indicate editing is not allowed if the order is complete' do
      expect(order.can_update_addresses?).to eq(true)
      order.update_attributes!(state: 'complete', completed_at: Time.now)
      expect(order.can_update_addresses?).to eq(false)
    end

    it 'should not change its address IDs if saved unmodified when complete' do
      a = create(:address)
      order.update_attributes!(state: 'complete', completed_at: Time.now, bill_address: a, ship_address: a)

      5.times do |t|
        begin
          expect {
            order.save!
          }.not_to change{ [order.reload.bill_address_id, order.ship_address_id] }
        rescue => e
          raise e.class, "Loop #{t}: #{e}"
        end
      end
    end
  end

  it 'touches addresses if assignments are changed' do
    a = create(:address)

    expect {
      order.bill_address = a
      order.save!
    }.to change{ a.reload.updated_at }

    expect {
      order.update_attributes!(ship_address_id: a.id)
    }.to change{ a.reload.updated_at }
  end

  it 'fails validation if it has invalid addresses' do
    o = create(:completed_order_with_pending_payment, user: user)
    expect(o).to be_valid

    # Make the addresses invalid and force the order to try to unlink them
    o.bill_address.update_columns(firstname: nil, lastname: nil, zipcode: nil, user_id: user.id)
    o.ship_address.update_columns(firstname: nil, lastname: nil, zipcode: nil, user_id: user.id)
    o.reload

    expect(o.bill_address.firstname).to be_blank
    expect(o.ship_address.firstname).to be_blank

    expect(o.save).to eq(false)
    expect(o.errors.full_messages.to_sentence).to match(/zip/i)
  end
end
