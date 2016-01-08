module AdminAddresses
  # Visits the address listing page for the given order or user, calling
  # #visit_user_addresses or #visit_order_addresses.
  #
  # Sets @user_id and @order_id.
  def visit_addresses(order_or_user)
    if order_or_user.is_a?(Spree::Order)
      @user_id = order_or_user.user_id
      @order_id = order_or_user.id
      visit_order_addresses order_or_user
    else
      @user_id = order_or_user.id
      @order_id = nil
      visit_user_addresses order_or_user
    end
  end

  # Visits the address listing page for the given user and performs basic
  # verification of selected addresses.
  def visit_user_addresses(user)
    visit spree.edit_admin_user_path(user)
    expect_address_list

    expect_user_addresses(user)
  end

  # Visits the address listing page for the given order and performs basic
  # verification of selected addresses.
  def visit_order_addresses(order)
    visit spree.admin_order_customer_path(order)
    expect_address_list

    expect_order_addresses(order)
    expect_user_addresses(order.user) if order.user
  end

  # Clicks the editing link for the given +address+ (numeric ID or address
  # object), using the addresses page for the given +order_or_user+.  If
  # +direct+ is true, then goes directly to the editing URL instead of visiting
  # the addresses page and clicking the link.  Verifies that the link led to
  # the correct path.
  def visit_edit_address(order_or_user, address, direct=false)
    address = address.id if address.is_a?(Spree::Address)

    if direct
      order_id = order_or_user.is_a?(Spree::Order) ? order_or_user.id : nil
      user_id = order_or_user.is_a?(Spree::User) ? order_or_user.id : order_or_user.user_id
      visit spree.edit_admin_address_path(address, order_id: order_id, user_id: user_id)
    else
      visit_addresses(order_or_user)
      click_link "edit-address-#{address}"
    end

    expect(current_path).to eq(spree.edit_admin_address_path(address))
  end

  # Expects the page to have an admin address list.
  def expect_address_list
    expect(page).to have_css('[data-hook="admin_addresses"]')
  end

  # Expects +count+ addresses on the address listing page.
  def expect_address_count(count)
    if count == 0
      expect{page.find('#addresses tbody tr')}.to raise_error(/CSS/i)
    else
      expect(page).to have_css('#addresses tbody tr', count: count)
    end
  end

  # Expects the +user+ addresses to be selected on the page, and expects every
  # user address to be present on the page.
  def expect_user_addresses(user)
    user.reload
    expect_selected(user.bill_address, :user, :bill)
    expect_selected(user.ship_address, :user, :ship)

    expect_list_addresses(user.addresses)
  end

  # Expects every address in the given +list+ to be displayed on the page,
  # using #content_regex to match deduplicated addresses.  If +present+ is
  # false, then the addresses are expected *not* to be displayed.
  def expect_list_addresses(list, present=true)
    list.each do |a|
      if present
        expect(page).to have_content(content_regex(a))
      else
        expect(page).to have_no_content(content_regex(a))
      end
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
    address = address.id if address.is_a?(Spree::Address) || address.is_a?(Spree::AddressBookGroup)

    group_selector = "//input[@type='radio' and @name='#{user_or_order}[#{bill_or_ship}_address_id]' and @checked]"
    item_selector = address_radio_selector(address, user_or_order, bill_or_ship)

    if address.nil?
      expect{page.find(:xpath, group_selector)}.to raise_error(/Unable to find xpath/i)
    else
      expect{page.find(:xpath, group_selector)}.not_to raise_error
      expect(page.find(item_selector)).to be_checked
    end
  end

  # Visits the addresses page of the given +order_or_user+, then selects the
  # specified +addresses+ (a Hash mapping one or more address types to IDs).
  #
  # Address type Hash keys:
  #   :user_bill - User default billing address
  #   :user_ship - User default shipping address
  #   :order_bill - Order billing address
  #   :order_ship - Order shipping address ID
  #   :fail - If present and truthy, then flash success will not be expected.
  def select_addresses(order_or_user, addresses={})
    visit_addresses(order_or_user)

    select_address(addresses[:user_bill], :user, :bill) if addresses[:user_bill]
    select_address(addresses[:user_ship], :user, :ship) if addresses[:user_ship]
    select_address(addresses[:order_bill], :order, :bill) if addresses[:order_bill]
    select_address(addresses[:order_ship], :order, :ship) if addresses[:order_ship]

    submit_addresses(!addresses[:fail])
  end

  # Clicks on the given address's radio button for the given address type.
  #   user_or_order - :user or :order
  #   bill_or_ship - :bill or :ship
  def select_address(address, user_or_order, bill_or_ship)
    item_selector = address_radio_selector(address, user_or_order, bill_or_ship)
    choose(item_selector[1..-1]) # Skip '#' character in ID string using 1..-1
  end

  # Returns a CSS selector to find the given address's radio button.
  def address_radio_selector(address, user_or_order, bill_or_ship)
    address = address.id if address.is_a?(Spree::Address)
    "##{user_or_order}_#{bill_or_ship}_address_id_#{address}"
  end

  # Clicks on the address page's submit button.  If success is true, then
  # expects to find a success message.  If false, it expects not to find a
  # success message.  Otherwise, success or failure is not checked.
  def submit_addresses(success=true)
    click_button I18n.t(:save_address_selection, scope: :address_book)

    if success == true
      expect(page).to have_content(I18n.t(:default_addresses_updated, scope: :address_book))
    elsif success == false
      expect(page).not_to have_content(I18n.t(:default_addresses_updated, scope: :address_book))
    end
  end

  # Returns a Regexp that will find the address's text, ignoring case.
  def content_regex(address)
    # Regexp.escape adds backslashes before spaces, so the second gsub was
    # necessary to get whitespace-insensitive matching.
    Regexp.new(Regexp.escape(CGI::unescapeHTML(address.to_s.gsub(/<[^>]+>/, ' '))).gsub(/(\\?\s+)+/, '\s+'), 'i')
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
    [uri.path, uri.query].map{|s| s if s.present? }.compact.join('?')
  end

  # Expects the current path and query string to match the order customer
  # details path for an order, or the user account details path for a user.
  def expect_address_collection_path(order_or_user)
    if order_or_user.is_a?(Spree::Order)
      path = spree.admin_order_customer_path(order_or_user)
    else
      path = spree.edit_admin_user_path(order_or_user)
    end

    expect(path_with_query).to eq(path)
  end

  # Visits the addresses pages for the given order or user, clicks the New
  # Address link, then fills out and submits the address form with +values+.
  # If +expect_success+ is true, the operation is expected to succeed.
  # Otherwise, it is expected to fail.  If +type+ is :user, :bill, or :ship,
  # then the address type field (for order addresses) will be set to User,
  # Billing, or Shipping, respectively (see #assign_order_address in
  # Spree::Admin::AddressesController).
  def create_address(order_or_user, expect_success, values, type=nil)
    visit_addresses(order_or_user)

    expect(page).to have_css('#new_address_link')
    click_link 'new_address_link'
    expect(current_path).to eq(spree.new_admin_address_path)

    fill_in_address(values, type)

    click_button Spree.t('actions.create')

    if expect_success
      expect_address_collection_path(order_or_user)
      expect(page).to have_content(Spree.t(:successfully_created, resource: Spree::Address.model_name.human))
    else
      expect(path_with_query).to eq(spree.admin_addresses_path(user_id: @user_id, order_id: @order_id))
      expect(page).to have_no_content(Spree.t(:successfully_created, resource: Spree::Address.model_name.human))
    end
  end

  # Visits the appropriate addresses page based on whether the target is a user
  # or an order, clicks the edit link for the given +address_id+, updates the
  # form with the given +values+ (a Hash passed iteratively to Capybara's
  # #fill_in method, or another Spree::Address to copy), then submits the form.
  # If +expect_success+ is true, then the operation is expected to succeed.
  # Otherwise, it is expected to fail.  If +type+ is :user, :bill, or :ship,
  # then the address type field (for order addresses) will be set to User,
  # Billing, or Shipping, respectively (see #assign_order_address in
  # Spree::Admin::AddressesController).
  def edit_address(order_or_user, address_id, expect_success, values, type=nil)
    visit_edit_address(order_or_user, address_id)
    fill_in_address(values, type)
    click_button Spree.t('actions.update')

    if expect_success
      expect_address_collection_path(order_or_user)
      expect(page).to have_content(Spree.t(:successfully_updated, resource: Spree::Address.model_name.human))
    else
      expect(page).to have_no_content(Spree.t(:successfully_updated, resource: Spree::Address.model_name.human))
      expect(path_with_query).to eq(spree.admin_address_path(address_id, user_id: @user_id, order_id: @order_id))
    end
  end

  # Visits the appropriate addresses page for the +order_or_user+, then clicks
  # the delete link for the given +address_id+.  If +expect_success+ is true,
  # then expects the address to have been deleted.
  def delete_address(order_or_user, address_id, expect_success)
    address_id = address_id.id if address_id.is_a?(Spree::Address)

    visit_addresses(order_or_user)

    click_link "delete-address-#{address_id}"

    if expect_success
      expect(page).to have_content(Spree.t(:successfully_removed, resource: Spree::Address.model_name.human))
    else
      expect(page).to have_no_content(Spree.t(:successfully_removed, resource: Spree::Address.model_name.human))
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

      [Spree::Order, Spree::User].each do |c|
        c.class_eval do
          alias_method :orig_can_update_addresses?, :can_update_addresses?
          def can_update_addresses?
            true
          end
        end
      end
    end

    after(:each) do
      # Restore original #editable? method
      Spree::Address.class_eval do
        alias_method :editable?, :orig_editable?
      end

      [Spree::Order, Spree::User].each do |c|
        c.class_eval do
          alias_method :can_update_addresses?, :orig_can_update_addresses?
        end
      end
    end
  end

  # Sets up before and after blocks that make all addresses deletable
  # (including complete orders) during each test in the current context.
  def make_addresses_deletable
    before(:each) do
      # Allow editing of completed order addresses
      Spree::Address.class_eval do
        alias_method :orig_can_be_deleted?, :can_be_deleted?
        def can_be_deleted?
          true
        end
      end

      [Spree::Order, Spree::User].each do |c|
        c.class_eval do
          alias_method :orig_del_can_update_addresses?, :can_update_addresses?
          def can_update_addresses?
            true
          end
        end
      end
    end

    after(:each) do
      # Restore original #can_be_deleted? method
      Spree::Address.class_eval do
        alias_method :can_be_deleted?, :orig_can_be_deleted?
      end

      [Spree::Order, Spree::User].each do |c|
        c.class_eval do
          alias_method :can_update_addresses?, :orig_del_can_update_addresses?
        end
      end
    end
  end

  # Sets up before and after blocks that enable or disable address assignment
  # for users if +enabled+ is true or false, respectively.
  def force_user_address_updates(enabled)
    before(:each) do
      # Allow or disallow user address assignment
      Spree::User.class_eval do
        alias_method :orig_can_update_addresses?, :can_update_addresses?

        if enabled
          def can_update_addresses?
            true
          end
        else
          def can_update_addresses?
            false
          end
        end
      end
    end

    after(:each) do
      # Restore original #can_update_addresses? method
      Spree::User.class_eval do
        alias_method :can_update_addresses?, :orig_can_update_addresses?
      end
    end
  end

  # Sets up before and after blocks that temporarily add a numerical validation
  # to Spree::Address#zipcode.
  def force_address_zipcode_numeric
    before(:each) do
      Spree::Address.class_eval do
        validates_numericality_of :zipcode
      end
    end

    after(:each) do
      # http://stackoverflow.com/a/11268726/737303 was useful
      Spree::Address._validators[:zipcode].reject!{|z| z.is_a?(ActiveModel::Validations::NumericalityValidator) }
      cb = Spree::Address._validate_callbacks.find{|z|
        z.raw_filter.is_a?(ActiveModel::Validations::NumericalityValidator) && z.raw_filter.attributes.include?(:zipcode)
      }
      Spree::Address._validate_callbacks.delete(cb)
    end
  end
end
