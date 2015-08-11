module AdminAddresses
  # Visits the address listing page for the given user and performs basic
  # verification of selected addresses.
  def visit_user_addresses(user)
    visit spree.admin_addresses_path(user_id: user.id)
    expect(page).to have_content(I18n.t(:new_address, scope: :address_book))

    expect_user_addresses(user)
  end

  # Visits the address listing page for the given order and performs basic
  # verification of selected addresses.
  def visit_order_addresses(order)
    visit spree.admin_addresses_path(order_id: order.id)
    expect(page).to have_content(I18n.t(:new_address, scope: :address_book))

    expect_order_addresses(order)
    expect_user_addresses(order.user) if order.user
  end

  # Expects +count+ addresses on the address listing page.
  def expect_address_count(count)
    if count == 0
      expect{page.find('#addresses tbody tr')}.to raise_error(/CSS/i)
    else
      expect(page.all('#addresses tbody tr').count).to eq(count)
    end
  end

  # Expects the +user+ addresses to be selected on the page, and expects every
  # user address to be present on the page.
  def expect_user_addresses(user)
    user.reload
    expect_selected(user.bill_address, :user, :bill)
    expect_selected(user.ship_address, :user, :ship)

    user.addresses.each do |a|
      expect(page).to have_content(content_regex(a))
    end
  end

  # Expects the +order+ addresses to be selected on the page, and expects every
  # order address to be present on the page.
  def expect_order_addresses(order)
    order.reload
    expect_selected(order.bill_address, :order, :bill)
    expect_selected(order.ship_address, :order, :ship)

    expect(page).to have_content(content_regex(order.bill_address)) if order.bill_address
    expect(page).to have_content(content_regex(order.ship_address)) if order.ship_address
  end

  # Expects the +address+ to be selected on the page for the user or order
  # shipping or billing address.  If +address+ is nil, expects the given
  # category not to have a selected address.
  #   user_or_order - :user or :order
  #   bill_or_ship - :bill or :ship
  def expect_selected(address, user_or_order, bill_or_ship)
    group_selector = "//input[@type='radio' and @name='#{user_or_order}[#{bill_or_ship}_address_id]' and @checked]"
    item_selector = address_radio_selector(address, user_or_order, bill_or_ship)

    if address.nil?
      expect{page.find(:xpath, group_selector)}.to raise_error(/Unable to find xpath/i)
    else
      expect{page.find(:xpath, group_selector)}.not_to raise_error
      expect(page.find(item_selector)).to be_checked
    end
  end

  # Clicks on the given address's radio button for the given address type.
  #   user_or_order - :user or :order
  #   bill_or_ship - :bill or :ship
  def select_address(address, user_or_order, bill_or_ship)
    item_selector = address_radio_selector(address, user_or_order, bill_or_ship)
    choose(item_selector[1..-1]) # Skip '#'
  end

  # Returns a CSS selector to find the given address's radio button.
  def address_radio_selector(address, user_or_order, bill_or_ship)
    "##{user_or_order}_#{bill_or_ship}_address_id_#{address.try(:id)}"
  end

  # Clicks on the address page's submit button.
  def submit_addresses
    click_button I18n.t(:update_default_addresses, scope: :address_book)
  end

  # Returns a Regexp that will find the address's text, ignoring case.
  def content_regex(address)
    # Regexp.escape adds backslashes before spaces, so the second gsub was
    # necessary to get whitespace-insensitive matching.
    Regexp.new(Regexp.escape(address.to_s.gsub(/<[^>]+>/, ' ')).gsub(/(\\?\s+)+/, '\s+'), 'i')
  end

  # Clones an address and returns the ID of the clone.
  def cloned_address_id(address)
    a = address.clone
    a.save!
    a.id
  end

  # Sets the user_id of the +order+'s addresses to nil, if addresses are
  # present.  Returns the order.
  def strip_order_address_users(order)
    order.bill_address.try(:update_attributes!, user_id: nil)
    order.ship_address.try(:update_attributes!, user_id: nil)
    order
  end

  # Returns the current Capybara page path plus query string (e.g. "/a?b=c").
  def path_with_query
    uri = URI.parse(page.current_url)
    "#{uri.path}?#{uri.query}"
  end

  # Fill in an already loaded admin address form with values from the given
  # +address+.  See also #fill_in_address in support/checkout_with_product.rb.
  def fill_in_admin_address(address)
    fill_in Spree.t(:first_name), with: address.firstname
    fill_in Spree.t(:last_name), with: address.lastname
    fill_in Spree.t(:company), with: address.company if Spree::Config[:company]
    fill_in Spree.t(:street_address), with: address.address1
    fill_in Spree.t(:street_address_2), with: address.address2
    select address.country.name, from: Spree.t(:country)
    fill_in Spree.t(:city), with: address.city
    fill_in Spree.t(:zip), with: address.zipcode
    select address.state.name, from: Spree.t(:state)
    fill_in Spree.t(:phone), with: address.phone
    fill_in Spree.t(:alternative_phone), with: address.alternative_phone if Spree::Config[:alternative_shipping_phone]
  end

  # Visits the appropriate addresses page based on whether +target+ is a user
  # or an order, clicks the edit link for the given +address_id+, updates the
  # form with the given +values+ (a Hash passed iteratively to Capybara's
  # #fill_in method, or another Spree::Address to copy), then submits the form.
  # If +expect_success+ is true, then the operation is expected to succeed.
  # Otherwise, it is expected to fail.
  def edit_address(order_or_user, address_id, expect_success, values)
    address_id = address_id.id if address_id.is_a?(Spree::Address)

    if order_or_user.is_a?(Spree::Order)
      user_id = order_or_user.user_id
      order_id = order_or_user.id
      visit_order_addresses order_or_user
    else
      user_id = order_or_user.id
      order_id = nil
      visit_user_addresses order_or_user
    end

    click_link "edit-address-#{address_id}"
    expect(current_path).to eq(spree.edit_admin_address_path(address_id))

    if values.is_a?(Spree::Address)
      fill_in_admin_address(values)
    elsif values.is_a?(Hash)
      values.each do |k, v|
        fill_in k, with: v
      end
    else
      raise "Invalid type #{values.class.name} for values"
    end

    click_button Spree.t('actions.update')

    if expect_success
      expect(path_with_query).to eq(spree.admin_addresses_path(user_id: user_id, order_id: order_id))
      expect(page).to have_content(Spree.t(:account_updated))
    else
      # TODO/FIXME - untested
      expect(path_with_query).to eq(spree.update_admin_address_path(address_id, user_id: user_id, order_id: order_id))
    end
  end
end

RSpec.configure do |c|
  c.include AdminAddresses

  # Sets up before and after blocks that make all addresses editable (including
  # complete orders) during each test in the current context.
  def make_addresses_editable
    before(:each) do
      # Allow editing of completed order addresses
      Spree::Address.class_eval do
        alias_method :orig_editable?, :editable?
        def editable?
          true
        end
      end
    end

    after(:each) do
      # Restore original #editable? method
      Spree::Address.class_eval do
        alias_method :editable?, :orig_editable?
      end
    end
  end
end
