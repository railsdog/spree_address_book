require 'spec_helper'

feature "Address selection during checkout" do
  include_context "store products"

  describe "as guest user" do
    include_context "checkout with product"
    before(:each) do
      restart_checkout
      fill_in "order_email", :with => "guest@example.com"
      click_button "Continue"
    end

    it "should only see billing address form" do
      within("#billing") do
        should_have_address_fields
        expect(page).to_not have_selector(".select_address")
      end
    end

    it "should only see shipping address form" do
      within("#shipping") do
        should_have_address_fields
        expect(page).to_not have_selector(".select_address")
      end
    end
  end

  describe "as authenticated user with saved addresses", :js => true do
    include_context "user with address"
    include_context "checkout with product"


    before(:each) { sign_in_to_cart!(user) }


    it "should not see billing or shipping address form" do
      find("#billing .inner").should_not be_visible
      find("#shipping .inner").should_not be_visible
    end

    it "should list saved addresses for billing and shipping" do
      within("#billing .select_address") do
        user.addresses.each do |a|
          expect(page).to have_field("order_bill_address_id_#{a.id}")
        end
      end
      within("#shipping .select_address") do
        user.addresses.each do |a|
          expect(page).to have_field("order_ship_address_id_#{a.id}")
        end
      end
    end

    it "should save 2 addresses for user if they are different" do
      expect do
        within("#billing") do
          choose I18n.t(:other_address, :scope => :address_book)
          fill_in_address(billing)
        end
        within("#shipping") do
          choose I18n.t(:other_address, :scope => :address_book)
          fill_in_address(shipping)
        end
        complete_checkout
      end.to change { user.addresses.count }.by(2)
    end

    it "should save 1 address for user if they are the same" do
      expect do
        within("#billing") do
          choose I18n.t(:other_address, :scope => :address_book)
          fill_in_address(billing)
        end
        within("#shipping") do
          choose I18n.t(:other_address, :scope => :address_book)
          fill_in_address(billing)
        end
        complete_checkout
      end.to change { user.addresses.count }.by(1)
    end

    describe "when invalid address is entered" do
      let(:address) do
        Spree::Address.new(:firstname => nil, :state => state)
      end

      it "should show address form with error" do
        within("#billing") do
          fill_in_address(address)
        end
        within("#shipping") do
          fill_in_address(address)
        end
        click_button "Save and Continue"
        within("#bfirstname") do
          expect(page).to have_content("field is required")
        end
        within("#sfirstname") do
          expect(page).to have_content("field is required")
        end
      end

      context 'with saved addresses and forced zipcode invalidation' do
        force_address_zipcode_numeric

        let(:address1) { build(:address, zipcode: 'INVALID ZIP CODE HEY') }
        let(:address2) { build(:address, zipcode: 'HEY SOME BROKEN ZIP CODE') }

        before(:each) do
          expect(address1).not_to be_valid
          expect(address2).not_to be_valid

          @a = create_list(:address, 5, user: user).first
          user.reload
          visit '/checkout/address'
        end

        it 'reloads form with errors for invalid addresses' do
          expect(address1.id).to be_nil
          expect(address2.id).to be_nil

          within '#billing' do
            choose I18n.t(:other_address, scope: :address_book)
            fill_in_address(address1)
          end

          within '#shipping' do
            choose I18n.t(:other_address, scope: :address_book)
            fill_in_address(address2)
          end

          expect(find_field('order_bill_address_attributes_zipcode').value).to eq(address1.zipcode)
          expect(find_field('order_ship_address_attributes_zipcode').value).to eq(address2.zipcode)

          click_button "Save and Continue"
          expect(current_path).to eq('/checkout/update/address')

          expect(user.orders.last.reload.bill_address_id).to be_nil
          expect(user.orders.last.ship_address_id).to be_nil

          expect_selected(0, :order, :bill)
          expect_selected(0, :order, :ship)

          expect(find_field('order_bill_address_attributes_zipcode').value).to eq(address1.zipcode)
          within '#billing' do
            expect(page).to have_content("is not a number")
          end

          expect(find_field('order_ship_address_attributes_zipcode').value).to eq(address2.zipcode)
          within '#shipping' do
            expect(page).to have_content("is not a number")
          end
        end

        it 'should preserve a selected address and select other ship address if the ship address fails validation' do
          choose "order_bill_address_id_#{@a.id}"

          within '#shipping' do
            begin # XXX
              choose I18n.t(:other_address, scope: :address_book)
            rescue => e
              whereami(e)
              puts page.html
              raise
            end
            fill_in_address(address1)
            fill_in Spree.t(:zipcode), with: 'notnumber'
          end

          # Making sure address was filled in
          expect(find_field('order_ship_address_attributes_firstname').value).to eq(address1.firstname)
          expect(find_field('order_ship_address_attributes_zipcode').value).to eq('notnumber')

          begin # XXX
            click_button Spree.t(:save_and_continue)

            # Making sure address is still there after reloading
            expect(find_field('order_ship_address_attributes_firstname').value).to eq(address1.firstname)
            expect(find_field('order_ship_address_attributes_zipcode').value).to eq('notnumber')

            expect(page).to have_text('is not a number')
            expect(current_path).to eq('/checkout/update/address')
          rescue => e
            whereami(e) # XXX
            puts page.html # XXX

            byebug # XXX

            raise
          end

          expect_selected(@a, :order, :bill)
          expect_selected(0, :order, :ship)

        end
      end
    end

    describe "entering 2 new addresses" do
      it "should assign 2 new addresses to order" do
        within("#billing") do
          choose I18n.t(:other_address, :scope => :address_book)
          fill_in_address(billing)
        end
        within("#shipping") do
          choose I18n.t(:other_address, :scope => :address_book)
          fill_in_address(shipping)
        end
        complete_checkout
        expect(page).to have_content("processed successfully")
        within("#order > div.row.steps-data > div:nth-child(1)") do
          expect(page).to have_content("Billing Address")
          expect(page).to have_content(expected_address_format(billing))
        end
        within("#order > div.row.steps-data > div:nth-child(2)") do
          expect(page).to have_content("Shipping Address")
          expect(page).to have_content(expected_address_format(shipping))
        end
      end
    end

    describe "using saved address for bill and new ship address" do
      let(:shipping) do
        FactoryGirl.create(:address, :address1 => Faker::Address.street_address,
          :state => state)
      end

      it "should save 1 new address for user" do
        expect do
          address = user.addresses.first
          choose "order_bill_address_id_#{address.id}"
          within("#shipping") do
            choose I18n.t(:other_address, :scope => :address_book)
            fill_in_address(shipping)
          end
          complete_checkout
        end.to change{ user.addresses.count }.by(1)
      end

      it "should assign addresses to orders" do
        address = user.addresses.first
        choose "order_bill_address_id_#{address.id}"
        within("#shipping") do
          choose I18n.t(:other_address, :scope => :address_book)
          fill_in_address(shipping)
        end
        complete_checkout
        expect(page).to have_content("processed successfully")
        within("#order > div.row.steps-data > div:nth-child(1)") do
          expect(page).to have_content("Billing Address")
          expect(page).to have_content(expected_address_format(address))
        end
        within("#order > div.row.steps-data > div:nth-child(2)") do
          expect(page).to have_content("Shipping Address")
          expect(page).to have_content(expected_address_format(shipping))
        end
      end

      it "should see form when new shipping address invalid" do
        address = user.addresses.first
        shipping = FactoryGirl.build(:address, :address1 => nil, :state => state)
        choose "order_bill_address_id_#{address.id}"
        within("#shipping") do
          choose I18n.t(:other_address, :scope => :address_book)
          fill_in_address(shipping)
        end
        click_button "Save and Continue"
        within("#saddress1") do
          expect(page).to have_content("field is required")
        end
        within("#billing") do
          find("#order_bill_address_id_#{address.id}").should be_checked
        end
      end
    end

    describe "using saved address for billing and shipping" do
      it "should addresses to order" do
        address = user.addresses.first
        choose "order_bill_address_id_#{address.id}"
        check "Use Billing Address"
        complete_checkout
        within("#order > div.row.steps-data > div:nth-child(1)") do
          expect(page).to have_content("Billing Address")
          expect(page).to have_content(expected_address_format(address))
        end
        within("#order > div.row.steps-data > div:nth-child(2)") do
          expect(page).to have_content("Shipping Address")
          expect(page).to have_content(expected_address_format(address))
        end
      end

      it "should not add addresses to user" do
        expect do
          address = user.addresses.first
          choose "order_bill_address_id_#{address.id}"
          check "Use Billing Address"
          complete_checkout
        end.to_not change{ user.addresses.count }
      end

      it 'should assign the the user default addresses to the order' do
        user.update_attributes!(
          bill_address_id: user.addresses.first.id,
          ship_address_id: create(:address, user: user).id
        )

        user.orders.delete_all
        add_mug_to_cart
        restart_checkout

        expect(user.orders.reload.last.bill_address_id).to eq(user.reload.bill_address_id)
        expect(user.orders.last.ship_address_id).to eq(user.ship_address_id)

        expect_selected(user.bill_address, :order, :bill)
        expect_selected(user.ship_address, :order, :ship)
      end

      it 'should select user addresses if the order has no saved addresses' do
        user.update_attributes!(
          bill_address_id: user.addresses.first.id,
          ship_address_id: create(:address, user: user).id
        )

        user.orders.last.update_attributes!(bill_address_id: nil, ship_address_id: nil)

        visit '/checkout/addresses'

        expect(user.orders.reload.last.bill_address_id).to be_nil
        expect(user.orders.last.ship_address_id).to be_nil

        expect_selected(user.bill_address, :order, :bill)
        expect_selected(user.ship_address, :order, :ship)
      end

      it 'should select the existing order addresses if the order has saved addresses' do
        user.update_attributes!(
          bill_address_id: user.addresses.first.id,
          ship_address_id: create(:address, user: user).id
        )

        user.orders.delete_all
        add_mug_to_cart
        restart_checkout

        bill = create(:address, user: user)
        ship = create(:address, user: user)
        user.orders.reload.last.update_attributes!(bill_address_id: bill.id, ship_address_id: ship.id)

        visit '/checkout/addresses'
        expect_selected(bill, :order, :bill)
        expect_selected(ship, :order, :ship)
      end

      it 'should select the first address if the user and order have no addresses' do
        user.update_attributes!(bill_address_id: nil, ship_address_id: nil)
        order.update_attributes!(bill_address_id: nil, ship_address_id: nil)

        create_list(:address, 3, user: user)
        expect(order.bill_address).to be_nil
        expect(order.ship_address).to be_nil
        expect(user.bill_address).to be_nil
        expect(user.ship_address).to be_nil

        l = Spree::AddressBookList.new(order, user.reload)

        visit '/checkout/addresses'
        expect_selected(l.first, :order, :bill)
        expect_selected(l.first, :order, :ship)
      end

      it 'should deduplicate listed addresses, only showing the newest' do
        user.addresses.delete_all
        5.times do
          create(:address, user: user).clone.save!
        end
        expect(user.addresses.count).to eq(10)

        # Expect 6 radio buttons (5 addresses, 1 'Other address')
        visit '/checkout/address'
        expect(page.all(:xpath, "//input[@type='radio' and @name='order[ship_address_id]']").count).to eq(6)
        expect(page.all(:xpath, "//input[@type='radio' and @name='order[bill_address_id]']").count).to eq(6)
      end

      it 'should not fill in the Other Address fields' do
        visit '/checkout/address'

        within '#billing' do
          choose I18n.t(:other_address, scope: :address_book)
        end

        within '#shipping' do
          choose I18n.t(:other_address, scope: :address_book)
        end

        expect(find_field('order_bill_address_attributes_firstname').value).to be_blank
        expect(find_field('order_ship_address_attributes_firstname').value).to be_blank
      end
    end

    describe "using saved address for ship and new bill address" do
      let(:billing) do
        FactoryGirl.create(:address, :address1 => Faker::Address.street_address, :state => state)
      end

      it "should save 1 new address for user" do
        expect do
          address = user.addresses.first
          choose "order_ship_address_id_#{address.id}"
          within("#billing") do
            choose I18n.t(:other_address, :scope => :address_book)
            fill_in_address(billing)
          end
          check "Use Billing Address"
          complete_checkout
        end.to change{ user.addresses.count }.by(1)
      end

      context 'with user address selection disabled' do
        force_user_address_updates(false)

        scenario 'selecting addresses does not save them to the user defaults' do
          expect {
            address = user.addresses.first
            choose "order_ship_address_id_#{address.id}"
            within("#billing") do
              choose I18n.t(:other_address, :scope => :address_book)
              fill_in_address(billing)
            end
            check "Use Billing Address"
            complete_checkout
          }.not_to change{ [user.bill_address_id, user.ship_address_id] }
        end
      end

      it "should assign addresses to orders" do
        choose "order_ship_address_id_#{address.id}"
        within("#billing") do
          choose I18n.t(:other_address, :scope => :address_book)
          fill_in_address(billing)
        end
        check "Use Billing Address"
        complete_checkout
        expect(page).to have_content("processed successfully")
        within("#order > div.row.steps-data > div:nth-child(1)") do
          expect(page).to have_content("Billing Address")
          expect(page).to have_content(expected_address_format(billing))
        end
        within("#order > div.row.steps-data > div:nth-child(2)") do
          expect(page).to have_content("Shipping Address")
          expect(page).to have_content(expected_address_format(billing))
        end
      end

      # TODO not passing because inline JS validation not working
      it "should see form when new billing address invalid" do
        address = user.addresses.first
        billing = FactoryGirl.build(:address, :address1 => nil, :state => state)
        choose "order_ship_address_id_#{address.id}"
        within("#billing") do
          choose I18n.t(:other_address, :scope => :address_book)
          fill_in_address(billing)
        end

        click_button "Save and Continue"
        within("#baddress1") do
          expect(page).to have_content("field is required")
        end
        within("#shipping") do
          find("#order_ship_address_id_#{address.id}").should be_checked
        end
      end
    end

    #TODO: This spec is failing because the same address can be saved multiple times
    describe "entering address that is already saved" do
      it "should not save address for user" do
        expect{
          address = user.addresses.first
          choose "order_ship_address_id_#{address.id}"
          within("#billing") do
            choose I18n.t(:other_address, :scope => :address_book)
            fill_in_address(address)
          end
          check "Use Billing Address"
          uaddrcount(user, 'RSPEC b4 checkout') # XXX
          complete_checkout
        }.not_to change { user.addresses.count }
      end
    end
  end
end
