Spree::CheckoutHelper.module_eval do
  # Outputs a checkbox to allow a user to indicate if we should save the address
  # as their default address.
  def save_default_address_check_box
    user = try_spree_current_user # To save a few characters

    # The user model doesn't support saving a default address
    return unless
      user.respond_to?(:persist_order_address) &&
      user.respond_to?(:ship_address_id) &&
      user.respond_to?(:bill_address_id)

    # For clarity
    has_defaults = user.bill_address_id? && user.ship_address_id?

    # By default don't overwrite their default address
    should_save = false

    # It should save if they don't already have a default
    should_save = true unless has_defaults

    # In general the user should be able to modify this input
    readonly = false

    # If they don't already have a default force them to
    readonly = true unless has_defaults

    # To work around the fact that readonly doesn't really stop a checkbox
    # from being enabled/disabled in HTML
    onclick = 'this.checked=!this.checked' if readonly

    # Build actual UI elements
    label = label_tag :save_user_address, Spree.t(:save_my_address)
    input = check_box_tag 'save_user_address', '1', should_save, readonly: readonly, onclick: onclick

    (input + label).html_safe
  end

  def use_billing_should_be_checked?
    same_address_id? || shipping_and_billing_blank? || shipping_present_and_billing_blank? || same_address_text? 
  end

  def same_address_id?
     @order.bill_address_id == @order.ship_address_id
  end

  def same_address_text?
     @order.bill_address.same_as?(@order.ship_address)
  end

  def shipping_present_and_billing_blank?
    @order.bill_address.present? && @order.ship_address.blank?
  end

  def shipping_and_billing_blank?
    @order.bill_address.blank? && @order.ship_address.blank?
  end
end
