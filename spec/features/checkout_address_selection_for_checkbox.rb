require 'spec_helper'

feature "Address selection during checkout" do
  include_context "store products"

  context 'as guest user', js: true do
    include_context "checkout with product"

    let(:address1) { build(:address, zipcode: '84000') }
    let(:address2) { build(:address, zipcode: '84111') }

    before(:each) do
      restart_checkout
      fill_in "order_email", :with => "guest@example.com"
      click_button "Continue"
    end

    it "order with identical shipping and billing addresses" do
      expect do #"the use_billing checkbox to be checked"
        within("#billing") do
          fill_in_address(address1)
        end
        within("#shipping") do
          uncheck 'order_use_billing'
          fill_in_address(address1)
        end
        click_button "Continue"
        visit(spree.checkout_state_path(:address))
        find("#order_use_billing").should be_checked 
      end.to change { Spree::Address.count }.by(2)
    end

    it "order with both shipping and billing addresses blank" do
      expect do #"the use_billing checkbox to be checked" 
        visit(current_path)
        find("#order_use_billing").should be_checked 
      end.to change { Spree::Address.count }.by(0)
    end

    it "order with billing address set and shipping address blank" do
      expect do #"the use_billing checkbox to be checked" 
        within("#billing") do
          fill_in_address(address1)
        end
        click_button "Continue"
        visit(spree.checkout_state_path(:address))
        find("#order_use_billing").should be_checked 
      end.to change { Spree::Address.count }.by(1)
    end

    it "order with shipping address set and billing address blank" do
      expect do #"the use_billing checkbox not to be checked" 
        within("#billing") do
          fill_in_address(address1)
        end
        within("#shipping") do
          uncheck 'order_use_billing'
          fill_in_address(address2)
        end
        click_button "Continue"
        Spree::Order.last.update_attributes!(bill_address_id: nil)
        visit(spree.checkout_state_path(:address))
        find("#order_use_billing").should_not be_checked 
      end.to change { Spree::Address.count }.by(2)
    end

    it "order with identical shipping and billing addresses" do
      expect do #"the use_billing checkbox to be checked" 
        within("#billing") do
          fill_in_address(address1)
        end
        within("#shipping") do
          uncheck 'order_use_billing'
          fill_in_address(address2)
        end
        click_button "Continue"
        visit(spree.checkout_state_path(:address))
        find("#order_use_billing").should_not be_checked 
        complete_checkout
      end.to change { Spree::Address.count }.by(2)
    end
  end

  describe "as authenticated user with saved addresses", :js => true do
    include_context "user with address"
    include_context "checkout with product"

    before(:each) { sign_in_to_cart!(user) }
  
    it "order with identical shipping and billing addresses (same ID)" do
      user.orders.last.update_attributes!(
        bill_address_id: user.addresses.first.id,
        ship_address_id: user.addresses.first.id,
      )
      visit(spree.checkout_state_path(:address))
      find("#order_ship_address_id_#{address.id}").should be_checked
    end

    it "order with identical shipping and billing addresses" do
      expect do 
        within("#billing") do
          choose I18n.t(:other_address, :scope => :address_book)
          fill_in_address(billing)
        end
        within("#shipping") do
          uncheck 'order_use_billing'
          choose I18n.t(:other_address, :scope => :address_book)
          fill_in_address(billing)
        end
        click_button "Continue"
        visit(spree.checkout_state_path(:address))
        find("#order_use_billing").should be_checked 
      end.to change { Spree::Address.count }.by(1)
    end

    it "order with both shipping and billing addresses blank" do
          expect do
            visit(spree.checkout_state_path(:address))
            find("#order_use_billing").should be_checked 
      end.to change { Spree::Address.count }.by(0)
    end

    it "order with billing address set and shipping address blank" do
      expect do
        within("#billing") do
          choose I18n.t(:other_address, :scope => :address_book)
          fill_in_address(billing)
        end
        click_button "Continue"
        visit(spree.checkout_state_path(:address))
        find("#order_use_billing").should be_checked 
      end.to change { Spree::Address.count }.by(1)
    end

    it "order with shipping address set and billing address blank" do
      expect do 
        within("#shipping") do
          uncheck 'order_use_billing'
          choose I18n.t(:other_address, :scope => :address_book)
          fill_in_address(shipping)
        end
        click_button "Continue"
        visit(spree.checkout_state_path(:address))
        find("#order_use_billing").should_not be_checked 
      end.to change { Spree::Address.count }.by(1)
    end

    it "order with identical shipping and billing addresses" do
      expect do 
        within("#billing") do
          choose I18n.t(:other_address, :scope => :address_book)
          fill_in_address(billing)
        end
        within("#shipping") do
          uncheck 'order_use_billing'
          choose I18n.t(:other_address, :scope => :address_book)
          fill_in_address(shipping)
        end
        click_button "Continue"
        visit(spree.checkout_state_path(:address))
        find("#order_use_billing").should_not be_checked 
      end.to change { Spree::Address.count }.by(2)
    end
  end
end
