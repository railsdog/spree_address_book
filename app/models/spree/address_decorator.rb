Spree::Address.class_eval do
  # This accessor allows the `f.select :address_type` to work in the admin
  # _address_form partial.
  attr_accessor :address_type

  # XXX
  before_validation ->{debug_addr(:before_validation)}
  before_save ->{debug_addr(:before_save)}
  # Too verbose XXX after_initialize ->{debug_addr(:after_initialize)}
  after_create ->{debug_addr(:after_create)}

  # XXX
  def debug_addr(step)
    $show_addr_creation ||= false
    if (self.user && $show_addr_creation) || step == :destroy
      puts "\e[32m==|#{step} address #{id.inspect} for user #{user_id.inspect}\e[0m"
      whereami(step)
    end
  end

  belongs_to :user, :class_name => Spree.user_class.to_s

  def self.required_fields
    Spree::Address.validators.map do |v|
      v.kind_of?(ActiveModel::Validations::PresenceValidator) ? v.attributes : []
    end.flatten
  end

  # Returns true if the other address's core data matches this address.
  # Ignores user_id if one of the addresses has a nil user ID.
  def same_as?(other)
    other = other.primary_address if other.is_a?(Spree::AddressBookGroup)
    return false unless other.is_a?(Spree::Address)

    if user_id.nil? != other.user_id.nil?
      comparison_attributes.except('user_id') == other.comparison_attributes.except('user_id')
    else
      comparison_attributes == other.comparison_attributes
    end
  end

  # Returns a subset of attributes for use by #same_as?, converted to lowercase
  # and whitespace-stripped for case insensitive comparison.
  def comparison_attributes
    except_list = ['id', 'updated_at', 'created_at', 'verified_at']
    except_list << 'alternative_phone' unless Spree::Config[:alternative_shipping_phone]
    except_list << 'company' unless Spree::Config[:company]

    a = attributes.except(*except_list)
    a.each{|k, v|
      if v.is_a?(String)
        v = v.downcase.strip.gsub(/\s+/, ' ')
        a[k] = v.present? ? v : nil
      end
    }
    a['state_name'] = nil if a['state_name'].blank?
    a
  end

  # can modify an address if it's not been used in an completed order
  # Users of the gem can override this method to provide different rules.
  # See also Spree::Order#can_update_addresses? and Spree::User#can_update_addresses?
  def editable?
    new_record? || (self.deleted_at.nil? && !Spree::Order.complete.with_address(self).any?)
  end

  def can_be_deleted?
    shipments.empty? && !Spree::Order.complete.with_address(self).any?
  end

  def to_s
    [
      "#{h firstname} #{h lastname}",
      "#{h company}",
      "#{h address1}",
      "#{h address2}",
      "#{h city} #{h state_text} #{h zipcode}",
      "#{h country}"
    ].reject(&:empty?).join(" <br/>").html_safe
  end

  # UPGRADE_CHECK if future versions of spree have a custom destroy function, this will break
  def destroy
    debug_addr(:destroy) # XXX

    # Remove the address from its user's default address slots
    if user && self.id
      user.bill_address_id = nil if user.bill_address_id == self.id
      user.ship_address_id = nil if user.ship_address_id == self.id
      user.save
    end

    # Remove the address from any incomplete orders
    Spree::Order.incomplete.with_bill_address(self).update_all(bill_address_id: nil)
    Spree::Order.incomplete.with_ship_address(self).update_all(ship_address_id: nil)

    # Remove the address from any users' default slots
    Spree::User.where(bill_address_id: self.id).update_all(bill_address_id: nil)
    Spree::User.where(ship_address_id: self.id).update_all(ship_address_id: nil)

    if can_be_deleted?
      super
    else
      update_column :deleted_at, Time.now
    end
  end

  # Returns a clone of this address with its user set to nil.  The returned
  # object will not have been saved to the database.
  def clone_without_user
    a = self.clone
    a.user = nil
    a
  end

  # Returns orders linked to this address, using the with_address order scope.
  def orders
    Spree::Order.with_address(self)
  end

  private
  def h(str)
    (str ? CGI::escapeHTML(str.to_s) : str).try(:html_safe)
  end
end
