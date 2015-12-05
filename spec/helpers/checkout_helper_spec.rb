require 'spec_helper'

describe Spree::CheckoutHelper do

  describe 'save_default_address_check_box' do

    it 'is ignored if invalid model' do
      helper.stub(:try_spree_current_user).and_return nil
      expect( helper.save_default_address_check_box ).to be_nil
    end

    it 'is checked and read-only if no existing default' do
      user = create :user
      expect( user.bill_address ).to be_nil
      expect( user.ship_address ).to be_nil
      helper.stub(:try_spree_current_user).and_return user
      output = helper.save_default_address_check_box
      expect( output ).to match /checked/
      expect( output ).to match /readonly/
    end

    it 'is unchecked and readonly otherwise' do
      user = create :user_with_addreses
      expect( user.bill_address ).not_to be_nil
      expect( user.ship_address ).not_to be_nil
      helper.stub(:try_spree_current_user).and_return user
      output = helper.save_default_address_check_box
      expect( output ).not_to match /checked/
      expect( output ).not_to match /readonly/
    end

  end

end
