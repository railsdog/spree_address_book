Spree.user_class.class_eval do
  has_many :addresses, -> { where(:deleted_at => nil).order("updated_at DESC") }, :class_name => 'Spree::Address'

  before_validation :link_address
  after_save :touch_addresses

  validate :verify_address_owners

  # Validates that the user's default addresses are owned by the user.
  def verify_address_owners
    if bill_address && bill_address.user != self
      errors.add(:bill_address, "Billing address belongs to #{bill_address.user_id.inspect}, not to this user #{id.inspect}")
    end

    if ship_address && ship_address.user != self
      errors.add(:ship_address, "Shipping address belongs to #{ship_address.user_id.inspect}, not to this user #{id.inspect}")
    end
  end

  # Updates the updated_at columns of the user's addresses, if they changed.
  def touch_addresses
    if changes.include?(:bill_address_id) && self.bill_address.present?
      self.bill_address.touch
    end

    if changes.include?(:ship_address_id) && self.ship_address.present?
      self.ship_address.touch
    end
  end

  # Pre-validation hook that adds user_id to addresses that are assigned to the
  # user's default address slots, and makes sure addresses are not shared with
  # completed orders.
  def link_address
    # TODO: Deduplicate code here, and with merge_user_addresses on the order model?

    if self.bill_address
      if !self.bill_address.new_record? && self.bill_address.orders.complete.any?
        self.bill_address = self.bill_address.clone
      end

      if !self.bill_address.user
        unless self.bill_address.editable?
          self.bill_address = self.bill_address.clone
        end
        self.bill_address.user = self
        self.bill_address.save unless self.bill_address.new_record? || !self.bill_address.valid?
      end
    end

    if self.ship_address
      if !self.ship_address.new_record? && self.ship_address.orders.complete.any?
        if self.ship_address.same_as?(self.bill_address)
          self.ship_address = self.bill_address
        else
          self.ship_address = self.ship_address.clone
        end
      end

      if !self.ship_address.user
        unless self.ship_address.editable?
          self.ship_address = self.ship_address.clone
        end
        self.ship_address.user = self
        self.ship_address.save unless self.ship_address.new_record? || !self.ship_address.valid?
      end
    end
  end

  # This is the method that Spree calls when the user has requested that the
  # address be their default address. Spree makes a copy from the order. Instead
  # we just want to reference the address so we don't create extra address objects.
  def persist_order_address(order)
    return unless can_update_addresses?

    update_attributes bill_address_id: order.bill_address_id

    # May not be present if delivery step has been removed
    update_attributes ship_address_id: order.ship_address_id if order.ship_address
  end

  # Returns true if this user's addresses can be edited or reassigned.  The
  # base implementation always returns true; users of the gem may override the
  # method to provide different behavior.  See also Spree::Address#editable?
  # and Spree::Order#can_update_addresses?
  def can_update_addresses?
    true
  end
end
