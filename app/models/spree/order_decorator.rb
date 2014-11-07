(Spree::PermittedAttributes.class_variable_get("@@checkout_attributes") << [
  :bill_address_id, :ship_address_id
]).flatten!

Spree::Order.class_eval do
  before_validation :clone_shipping_address, :if => "Spree::AddressBook::Config[:disable_bill_address]"

  def clone_shipping_address
    if self.ship_address
      self.bill_address = self.ship_address
    end
    true
  end

  def clone_billing_address
    if self.bill_address
      self.ship_address = self.bill_address
    end
    true
  end

  def bill_address_id=(id)
    address = Spree::Address.where(:id => id).first
    if address && address.user_id == self.user_id
      self["bill_address_id"] = address.id
      self.bill_address.reload
    else
      self["bill_address_id"] = nil
    end
  end

  def bill_address_attributes=(attributes)
    self.bill_address = update_or_create_address(attributes)
  end

  def ship_address_id=(id)
    address = Spree::Address.where(:id => id).first
    if address && address.user_id == self.user_id
      self["ship_address_id"] = address.id
      self.ship_address.reload
    else
      self["ship_address_id"] = nil
    end
  end

  def ship_address_attributes=(attributes)
    self.ship_address = update_or_create_address(attributes)
  end

  def save_current_order_addresses(billing, shipping, address)
    self.update_attributes(bill_address_id: address.id) if billing.present?
    self.update_attributes(ship_address_id: address.id) if shipping.present?
  end

  # Override default spree implementation to reference address instead of
  # copying the address. Also unlike stock spree, we copy the ship address even
  # if there is no delivery state for completeness.
  def assign_default_addresses!
    if self.user
      self.bill_address_id = user.bill_address_id if !self.bill_address_id && user.bill_address.try(:valid?)
      self.ship_address_id = user.ship_address_id if !self.ship_address_id && user.ship_address.try(:valid?)
    end
  end

  private

  # Updates an existing address or creates a new one
  # if the address already exists it will only update its attributes
  # in case the address is +editable?+
  def update_or_create_address(attributes)

    if attributes[:id]
      address = Spree::Address.find(attributes[:id])
      if address.editable?
        address.update_attributes(attributes)
      else
        address.errors.add(:base, I18n.t(:address_not_editable, scope: [:address_book]))
      end
    else
      address = Spree::Address.create(attributes)
    end
    address
  end
end
