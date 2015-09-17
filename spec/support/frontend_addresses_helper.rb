module FrontendAddresses
  # Visits the frontend account page, then clicks the address deletion link for
  # the given +address+ (numeric ID or Spree::Address).
  def remove_frontend_address(user, address, expect_success)
    address = address.id if address.is_a?(Spree::Address)

    visit spree.account_path
    click_link "remove_address_#{address}"

    if expect_success
      expect(current_path).to eq(spree.account_path)
      expect(page).to have_content(Spree.t(:successfully_removed, :resource => Spree.t(:address1)))
      expect_frontend_addresses(user)
    else
      expect(page).to have_no_content(Spree.t(:successfully_removed, :resource => Spree.t(:address1)))
    end
  end

  # Visits the frontend account page, clicks the address creation link, fills
  # in the given +values+ using #fill_in_address, then submits the form.
  #
  # If +default_bill+ and/or +default_ship+ are true or false, then the default
  # billing and/or shipping address checkboxes will be checked or unchecked
  # before submitting the form.
  def create_frontend_address(user, expect_success, values, default_bill=nil, default_ship=nil)
    visit spree.account_path
    click_link I18n.t(:add_new_address, :scope => :address_book)
    expect(current_path).to eq(spree.new_address_path)

    fill_in_address(values)
    check_frontend_defaults(default_bill, default_ship)

    click_button Spree.t(:create)

    if expect_success
      expect(page).to have_content(Spree.t(:successfully_created, :resource => Spree.t(:address1)))
      expect(current_path).to eq(spree.account_path)
      expect_frontend_addresses(user)
    else
      expect(page).to have_no_content(Spree.t(:successfully_created, :resource => Spree.t(:address1)))
    end
  end

  # Visits the frontend account page, clicks the address editing link for the
  # given +address+ (numeric ID or Spree::Address), fills in the given +values+
  # using #fill_in_address (spec/support/admin_addresses_helper.rb), then
  # submits the form.
  #
  # If +address+ is nil, then the first address on the page will be edited.
  #
  # If +default_bill+ and/or +default_ship+ are true or false, then the default
  # billing and/or shipping address checkboxes will be checked or unchecked
  # before submitting the form.
  def edit_frontend_address(user, address, expect_success, values, default_bill=nil, default_ship=nil)
    address = address.id if address.is_a?(Spree::Address)

    visit spree.account_path
    if address
      click_link "edit_address_#{address}"
      expect(current_path).to eq(spree.edit_address_path(address))
    else
      within('#addresses > tbody > tr:first-child') do
        click_link Spree.t(:edit)
      end
    end

    fill_in_address(values)
    check_frontend_defaults(default_bill, default_ship)

    click_button Spree.t(:update)

    if expect_success
      expect(page).to have_content(Spree.t(:successfully_updated, :resource => Spree.t(:address1)))
      expect(current_path).to eq(spree.account_path)
      expect_frontend_addresses(user)
    else
      expect(page).to have_no_content(Spree.t(:successfully_updated, :resource => Spree.t(:address1)))
    end
  end

  # Checks or unchecks default address selection checkboxes if +default_bill+
  # and/or +default_ship+ are true or false (takes no action for nil
  # parameters).
  def check_frontend_defaults(default_bill=nil, default_ship=nil)
    if default_bill
      check 'default_bill'
    elsif default_bill == false
      uncheck 'default_bill'
    end

    if default_ship
      check 'default_ship'
    elsif default_ship == false
      uncheck 'default_ship'
    end
  end

  # Expects the given +user+'s addresses to be listed, with default addresses
  # annotated.
  def expect_frontend_addresses(user)
    expect_list_addresses(user.reload.addresses)

    l = Spree::AddressBookList.new(user)
    if l.user_bill
      within(%Q{tr.address[data-address="#{l.user_bill.id}"]}) do
        expect(page).to have_content(Spree.t(:default_billing_address))
      end
    end

    if l.user_ship
      within(%Q{tr.address[data-address="#{l.user_ship.id}"]}) do
        expect(page).to have_content(Spree.t(:default_shipping_address))
      end
    end
  end
end

RSpec.configure do |c|
  c.include FrontendAddresses, type: :feature
end
