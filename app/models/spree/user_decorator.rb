Spree.user_class.class_eval do
  has_many :addresses, -> { where(:deleted_at => nil).order("updated_at DESC") }, :class_name => 'Spree::Address'

  after_save :link_address

  before_validation { uaddrcount(self.id ? self : nil, "U:B4VALIDATION") } # XXX
  before_save { uaddrcount(self.id ? self : nil, "U:B4SAVE") } # XXX
  after_save { uaddrcount(self.id ? self : nil, "U:AftSAVE") } # XXX



  def link_address
    uaddrcount self, "U:la:b4" # XXX
    # TODO: Handle assignment of order-specific address if the order is complete (where is this called?)
    r = true
    r &= bill_address.update_attributes!(user_id: id) if bill_address_id_changed? && bill_address
    r &= ship_address.update_attributes!(user_id: id) if ship_address_id_changed? && ship_address
    uaddrcount self, "U:la:aft(#{r.inspect}/#{bill_address.try(:errors).try(:full_messages)}/#{ship_address.try(:errors).try(:full_messages)})" # XXX
    r
  end

  def save_default_addresses(billing, shipping, address)
    uaddrcount self, "U:sda:b4" # XXX
    # TODO: is this supposed to set both to the same address ID?
    r = update_attributes(bill_address_id: address.id) if billing.present?
    r &= update_attributes(ship_address_id: address.id) if shipping.present?
    uaddrcount self, "U:sda:aft(#{r.inspect}/#{errors.full_messages})" # XXX
    r
  end

  # This is the method that Spree calls when the user has requested that the
  # address be their default address. Spree makes a copy from the order. Instead
  # we just want to reference the address so we don't create extra address objects.
  def persist_order_address(order)
    uaddrcount self, "U:poa:b4", order: order # XXX
    r = update_attributes bill_address_id: order.bill_address_id

    # May not be present if delivery step has been removed
    r &= update_attributes ship_address_id: order.ship_address_id if order.ship_address
    uaddrcount self, "U:poa:aft(#{r.inspect}/#{errors.full_messages})", order: order # XXX
    r
  end
end
