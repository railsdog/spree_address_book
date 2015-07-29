Spree.user_class.class_eval do
  after_save :link_address

  has_many :addresses, -> { where(:deleted_at => nil).order("updated_at DESC") }, :class_name => 'Spree::Address'

  def link_address
    # TODO: Handle assignment of order-specific address if the order is complete (where is this called?)
    bill_address.update_attributes(user_id: id) if bill_address_id_changed? && bill_address
    ship_address.update_attributes(user_id: id) if ship_address_id_changed? && ship_address
  end

  def save_default_addresses(billing, shipping, address)
    # TODO: is this supposed to set both to the same address ID?
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
