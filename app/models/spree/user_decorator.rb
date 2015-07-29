Spree.user_class.class_eval do
  after_save :link_address

  has_many :addresses, -> { where(:deleted_at => nil).order("updated_at DESC") }, :class_name => 'Spree::Address'

  # This method merges the addresses related to the user
  # plus order's bill and ship addresses returning a unique
  # array of addresses based on attributes.
  def user_and_order_addresses(order)
    raise 'Order is not owned by this user!' unless order.user_id == self.id

    addresses = [self.addresses, order.bill_address, order.ship_address].flatten.compact
    addresses.uniq! { |a| a.comparison_attributes.except('user_id') }
    addresses.sort_by(&:updated_at).reverse
  end

  def link_address
    # TODO: Handle assignment of order-specific address if the order is complete (where is this called?)
    bill_address.update_attributes(user_id: id) if bill_address_id_changed? && bill_address
    ship_address.update_attributes(user_id: id) if ship_address_id_changed? && ship_address
  end

  def save_default_addresses(billing, shipping, address)
    update_attributes(bill_address_id: address.id) if billing.present?
    update_attributes(ship_address_id: address.id) if shipping.present?
  end

  # This is the method that Spree calls when the user has requested that the
  # address be their default address. Spree makes a copy from the order. Instead
  # we just want to reference the address so we don't create extra address objects.
  def persist_order_address(order)
    update_attributes bill_address_id: order.bill_address_id

    # May not be present if delivery step has been removed
    update_attributes ship_address_id: order.ship_address_id if order.ship_address
  end
end
