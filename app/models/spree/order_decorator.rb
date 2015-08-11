Spree::PermittedAttributes.class_variable_get("@@checkout_attributes").concat [:bill_address_id, :ship_address_id]

Spree::Order.class_eval do
  before_validation :clone_shipping_address, :if => "Spree::AddressBook::Config[:disable_bill_address]"

  state_machine.after_transition to: :complete, do: :delink_addresses
  before_validation :delink_addresses_validation, if: :complete?
  before_validation :merge_user_addresses, unless: :complete?

  before_validation ->{puts "VALIDATION #{state} #{id}"} # XXX
  before_save ->{puts "SAVE #{state} #{id}"} # XXX

  def clone_shipping_address
    if self.ship_address
      self.bill_address = self.ship_address
    end
    true
  end

  # Overrides Spree's #clone_billing_address to link the existing record rather
  # than cloning the address or modifying the shipping address record.  Address
  # cloning is handled by #delink_addresses.
  def clone_billing_address
    puts "O: Clone billing on #{id} change #{ship_address_id.inspect} to #{bill_address_id.inspect}" # XXX
    uaddrcount(user, "O:b4", order: self) # XXX

    if self.bill_address
      self.ship_address = self.bill_address
    end
    uaddrcount(user, "O:aft", order: self) # XXX
    true
  end

  def bill_address_id=(id)
    uaddrcount(user, "O:bai=:b4", order: self) # XXX
    address = Spree::Address.where(:id => id).first
    if address && address.user_id == self.user_id
      self["bill_address_id"] = address.id
      a = self.bill_address.reload
    else
      a = self["bill_address_id"] = nil
    end

    uaddrcount(user, "O:bai=:aft", order: self) # XXX

    a
  end

  def bill_address_attributes=(attributes)
    uaddrcount(user, "O:baa=:b4", order: self) # XXX
    self.bill_address = update_or_create_address(attributes)
    uaddrcount(user, "O:baa=:aft", order: self) # XXX
    self.bill_address
  end

  def ship_address_id=(id)
    uaddrcount(user, "O:sai=:b4", order: self) # XXX
    address = Spree::Address.where(:id => id).first
    if address && address.user_id == self.user_id
      self["ship_address_id"] = address.id
      a = self.ship_address.reload
    else
      a = self["ship_address_id"] = nil
    end
    uaddrcount(user, "O:sai=:aft", order: self) # XXX

    a
  end

  def ship_address_attributes=(attributes)
    uaddrcount(user, "O:sae=:b4", order: self) # XXX
    self.ship_address = update_or_create_address(attributes)
    uaddrcount(user, "O:sae=:aft", order: self) # XXX
    self.ship_address
  end

  def save_current_order_addresses(billing, shipping, address)
    uaddrcount(user, "O:scoa:b4", order: self) # XXX
    res = self.update_attributes(bill_address_id: address.id) if billing.present?
    res &= self.update_attributes(ship_address_id: address.id) if shipping.present?
    uaddrcount(user, "O:scoa:aft(#{res.inspect})", order: self) # XXX

    res
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

  # While an order is in progress it refers to the same object as is in the
  # address book (i.e. it is a reference). This makes the UI code easier. Once a
  # order is complete we want to copy clone the address so the order/shipments
  # have their own copy. This preserves the historical data should the addresses
  # in the address book be changed or removed.
  def delink_addresses
    delink_addresses_validation
    save!
  end

  # Delinks addresses without validating, for use in a before_validation
  # callback.
  def delink_addresses_validation
    uaddrcount(user, "O:dav:b4", order: self) # XXX
    if bill_address.try(:user_id)
      bill_copy = bill_address.clone_without_user
      bill_copy.save!
      self.bill_address = bill_copy
    end

    if ship_address.try(:user_id)
      ship_copy = ship_address.clone_without_user
      ship_copy.save!
      self.ship_address = ship_copy
      shipments.update_all address_id: ship_address_id
    end
    uaddrcount(user, "O:dav:aft", order: self) # XXX
  end

  # Copies new addresses from incomplete orders to users, switches order
  # addresses to user addresses if matching addresses exist.
  def merge_user_addresses
    uaddrcount(user, "O:mua:b4", order: self) # XXX

    result = true

    if user
      l = Spree::AddressBookList.new(user)

      if self.bill_address
        bill = l.find(self.bill_address)
        if bill
          if self.bill_address_id != bill.id
            oldbill = self.bill_address
            self.bill_address_id = bill.primary_address.id
            oldbill.destroy
          end
        elsif self.bill_address.user_id.nil?
          result &= self.bill_address.update_attributes(user_id: self.user_id)
        end
      end

      if self.ship_address
        if self.ship_address.same_as?(self.bill_address)
          self.ship_address_id = self.bill_address_id
        else
          ship = l.find(self.ship_address)
          if ship
            if self.ship_address_id != ship.id
              oldship = self.ship_address
              self.ship_address_id = ship.primary_address.id
              oldship.destroy
            end
          elsif self.ship_address.user_id.nil?
            result &= self.ship_address.update_attributes(user_id: self.user_id) # TODO: just use =?
          end
        end
      end

      user.addresses.reload
    end

    uaddrcount(user, "O:mua:aft(#{result.inspect})", order: self) # XXX

    result
  end

  # Updates an existing address or creates a new one
  # if the address already exists it will only update its attributes
  # in case the address is +editable?+
  def update_or_create_address(attributes)
    uaddrcount(user, "O:uoca:b4", order: self) # XXX
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
    uaddrcount(user, "O:uoca:aft", order: self) # XXX
    address
  end
end
