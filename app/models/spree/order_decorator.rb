Spree::PermittedAttributes.class_variable_get("@@checkout_attributes").concat [:bill_address_id, :ship_address_id]

Spree::Order.class_eval do
  before_validation :clone_shipping_address, :if => "Spree::AddressBook::Config[:disable_bill_address]"

  state_machine.after_transition to: :complete, do: :delink_addresses
  before_validation :delink_addresses_validation, if: :complete?
  before_validation :merge_user_addresses, unless: :complete?

  before_validation { uaddrcount(user, "O:B4VALIDATION #{state} #{id.inspect}", order: self) } # XXX
  before_save { uaddrcount(user, "O:B4SAVE #{state} #{id.inspect}", order: self) } # XXX
  after_save { uaddrcount(user, "O:AftSAVE #{state} #{id.inspect}", order: self) } # XXX

  # XXX / TODO: Probably want to get rid of this validation before deploying to
  # production because there is old invalid data.  Alternatively, limit
  # validation to orders created after a certain date (override in user of gem)
  validate :verify_address_owners

  # XXX
  # Validates that the addresses on the order are owned by an incomplete
  # order's user, if it has one, or not owned at all for complete orders.
  def verify_address_owners
    if complete?
      errors.add(:bill_address, 'Billing address should not have a user') if bill_address.try(:user_id)
      errors.add(:ship_address, 'Shipping address should not have a user') if ship_address.try(:user_id)
    else
      if bill_address && bill_address.user_id != user_id
        errors.add(
          :bill_address,
          "Billing address user #{bill_address.user_id.inspect} does not match order #{user_id.inspect}"
        )
      end

      if ship_address && ship_address.user_id != user_id
        errors.add(
          :ship_address,
          "Shipping address user #{ship_address.user_id.inspect} does not match order #{user_id.inspect}"
        )
      end
    end
  end


  # Returns orders that have the given +address+ as billing or shipping address.
  scope :with_address, ->(address){
    where('bill_address_id = :id OR ship_address_id = :id', id: address)
  }

  # Returns orders that have the given +address+ as billing address.
  scope :with_bill_address, ->(address){
    where(bill_address_id: address)
  }

  # Returns orders that have the given +address+ as shipping address.
  scope :with_ship_address, ->(address){
    where(ship_address_id: address)
  }


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

  # Disallow assignment of other users' addresses as the billing address.
  def bill_address_id=(id)
    uaddrcount(user, "O:bai=:b4", order: self) # XXX
    a = check_address_owner(id, :bill)
    uaddrcount(user, "O:bai=:aft", order: self) # XXX

    a
  end

  def bill_address_attributes=(attributes)
    uaddrcount(user, "O:baa=:b4", order: self) # XXX
    self.bill_address = update_or_create_address(attributes)
    uaddrcount(user, "O:baa=:aft", order: self) # XXX
    self.bill_address
  end

  # Disallow assignment of other users' addresses as the shipping address.
  def ship_address_id=(id)
    uaddrcount(user, "O:sai=:b4", order: self) # XXX
    a = check_address_owner(id, :ship)
    uaddrcount(user, "O:sai=:aft", order: self) # XXX

    a
  end

  def ship_address_attributes=(attributes)
    uaddrcount(user, "O:sae=:b4", order: self) # XXX
    self.ship_address = update_or_create_address(attributes)
    uaddrcount(user, "O:sae=:aft", order: self) # XXX
    self.ship_address
  end

  # Verifies ownership of the address given by +id+, then assigns it to this
  # order's address of the given +type+ (:bill or :ship).  Used by
  # #bill_address_id= and #ship_address_id= to prevent assignment of other
  # users' addresses.
  #
  # Raises an error if another user's address is assigned.  This cannot be
  # implemented as a validation because address delinking is performed in a
  # before_validation hook.
  def check_address_owner(id, type)
    if a = Spree::Address.find_by_id(id)
      if a.user_id.present? && a.user_id != self.user_id
        raise "Attempt to assign address #{a.id.inspect} from user #{a.user_id.inspect} to order #{self.number} from user #{self.user_id.inspect}"
      end
    end

    id = a.try(:id)
    if type == :bill
      self['bill_address_id'] = id
      self.bill_address.try(:reload) if id
    else
      self['ship_address_id'] = id
      self.ship_address.try(:reload) if id
    end
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

  # Returns true if this order should allow its addresses to be edited or
  # reassigned, false otherwise.  Users of the gem may override this method to
  # provide different behavior.  See also Spree::User#can_update_addresses? and
  # Spree::Address#editable?
  def can_update_addresses?
    !complete?
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
  # callback.  Ensures complete orders have two separate address objects.
  def delink_addresses_validation
    uaddrcount(user, "O:dav:b4", order: self) # XXX
    if bill_address.try(:user_id)
      bill_copy = bill_address.clone_without_user
      bill_copy.save!
      self.bill_address = bill_copy
    end

    if ship_address && (ship_address.user_id || (ship_address.id && ship_address.id == bill_address.try(:id)) || ship_address == bill_address)
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
    whereami('O:mua:b4') # XXX

    result = true

    if user
      uaddrcount(user, "O:mua:A", order: self) # XXX

      l = Spree::AddressBookList.new(user)

      if self.bill_address
        uaddrcount(user, "O:mua:BILL", order: self) # XXX

        bill = l.find(self.bill_address)
        if bill
          puts "FOUND BILL (#{bill.primary_address.try(:id).inspect})" # XXX
          if self.bill_address_id != bill.id
            puts "SET FOUND BILL (old: #{self.bill_address.try(:id).inspect})" # XXX
            oldbill = self.bill_address
            self.bill_address_id = bill.primary_address.id
            oldbill.destroy
          end
        elsif self.bill_address.user_id.nil?
          puts "GIVE BILL TO USER" # XXX
          whereami('GIVE BILL') # XXX
          result &= self.bill_address.update_attributes(user_id: self.user_id)
        end
      end

      if self.ship_address
        uaddrcount(user, "O:mua:SHIP", order: self) # XXX

        if self.ship_address.same_as?(self.bill_address)
          puts "SHIP SAME AS BILL ADDRESS; SHARING ID" # XXX
          self.ship_address_id = self.bill_address_id
        else
          ship = l.find(self.ship_address)
          if ship
            puts "FOUND SHIP (#{ship.primary_address.try(:id).inspect})" # XXX
            if self.ship_address_id != ship.id
              puts "SET FOUND SHIP (old: #{self.ship_address.try(:id).inspect})" # XXX
              oldship = self.ship_address
              self.ship_address_id = ship.primary_address.id
              oldship.destroy
            end
          elsif self.ship_address.user_id.nil?
            puts "GIVE SHIP TO USER" # XXX
            whereami('GIVE SHIP') # XXX
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
    whereami('O:uoca:b4')

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
