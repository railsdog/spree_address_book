require 'spec_helper'

describe Spree::Address do

  # Test spree_address_book's address_decorator.rb.
  describe 'spree_address_book address_decorator' do
    let(:address) { FactoryGirl.create(:address) }
    let(:address2) { FactoryGirl.create(:address) }
    let(:order) { FactoryGirl.create(:order) }
    let(:user) { FactoryGirl.create(:user) }

    before {
      order.bill_address = address2
      order.save
    }

    it 'has required attributes' do
      Spree::Address.required_fields.should eq([:firstname, :lastname, :address1, :city, :country, :zipcode, :phone])
    end

    it 'is editable' do
      address.should be_editable
    end

    it 'can be deleted' do
      address.should be_can_be_deleted
    end

    it "isn't editable when there is an associated order" do
      # TODO need to simulate completing an order
      # address2.should_not be_editable
    end

    it "can't be deleted when there is an associated order" do
      address2.should_not be_can_be_deleted
    end

    it 'is displayed as string' do
      a = address
      address.to_s.should eq("#{a.firstname} #{a.lastname} <br/>#{a.company} <br/>#{a.address1} <br/>#{a.address2} <br/>#{a.city} #{a.state_text} #{a.zipcode} <br/>#{a.country}".html_safe)
    end

    it 'is destroyed without saving used' do
      address.destroy
      Spree::Address.where(["id = (?)", address.id]).should be_empty
    end

    it 'is destroyed deleted timestamp' do
      address2.destroy
      Spree::Address.where(["id = (?)", address2.id]).should_not be_empty
    end

    it 'is removed as default when destroyed' do
      user.update_attributes!(bill_address_id: address.id, ship_address_id: address2.id)

      # Make sure the various model hooks didn't override the ID assignments
      expect(address.reload.user).to eq(user)
      expect(address2.reload.user).to eq(user)
      expect(user.bill_address_id).to eq(address.id)
      expect(user.ship_address_id).to eq(address2.id)

      address.destroy
      expect(user.reload.bill_address_id).to be_nil
      expect(user.ship_address_id).to eq(address2.id)

      address2.destroy
      expect(user.reload.bill_address_id).to be_nil
      expect(user.ship_address_id).to be_nil
    end

    describe '#same_as?' do
      let(:address) { a = FactoryGirl.create(:address); a.state_name = nil; a }
      let(:address2) { FactoryGirl.create(:address) }
      let(:address_copy) { a = address.clone; a.save!; a }
      let(:address_upper) {
        Spree::Address.create!(Hash[*address.attributes.map{|k, v| [k, v.is_a?(String) ? v.upcase : v]}.flatten].merge(id: nil))
      }
      let(:address_lower) {
        Spree::Address.create!(Hash[*address.attributes.map{|k, v| [k, v.is_a?(String) ? v.downcase : v]}.flatten].merge(id: nil))
      }
      let(:address_blank_state) {
        a = address.clone
        a.save!
        a.state_name = ''
        a
      }

      it 'returns true for the same address' do
        expect(address.same_as?(address)).to eq(true)
      end

      it 'returns false for different addresses' do
        expect(address.same_as?(address2)).to eq(false)
        expect(address2.same_as?(address)).to eq(false)
      end

      it 'returns true for a copy of the address' do
        expect(address.id).not_to eq(address_copy.id)
        expect(address.same_as?(address_copy)).to eq(true)
        expect(address_copy.same_as?(address)).to eq(true)
      end

      it 'returns true for a nil vs. blank state name' do
        expect(address == address_blank_state).to eq(false)
        expect(address.same_as?(address_blank_state)).to eq(true)
        expect(address_blank_state.same_as?(address)).to eq(true)
      end

      it 'returns true regardless of uppercase/lowercase' do
        expect(address.firstname == address_upper.firstname).to eq(false)
        expect(address.same_as?(address_upper)).to eq(true)
        expect(address_upper.same_as?(address)).to eq(true)
        expect(address.same_as?(address_lower)).to eq(true)
        expect(address_lower.same_as?(address)).to eq(true)
        expect(address_lower.same_as?(address_upper)).to eq(true)
        expect(address_upper.same_as?(address_lower)).to eq(true)
      end

      it 'returns true regardless of spacing' do
        a1 = address.clone
        a2 = address_copy.clone
        a1.update_attributes!(firstname: " First\n\tName Here\r\n")
        a2.update_attributes!(firstname: "First Name\tHere")
        expect(a1).to be_same_as(a2)
        expect(a2).to be_same_as(a1)
      end

      it 'returns false for two different users' do
        address.update_attributes!(user: create(:user))
        address_copy.update_attributes!(user: create(:user))
        expect(address.same_as?(address_copy)).to eq(false)
        expect(address_copy.same_as?(address)).to eq(false)
      end

      it 'returns true for same users' do
        address.update_attributes!(user: create(:user))
        address_copy.update_attributes!(user: address.user)
        expect(address.same_as?(address_copy)).to eq(true)
        expect(address_copy.same_as?(address)).to eq(true)
      end

      it 'returns true if one user is nil' do
        address.update_attributes!(user: create(:user))
        expect(address.same_as?(address_copy)).to eq(true)
        expect(address_copy.same_as?(address)).to eq(true)
      end
    end
  end
end
