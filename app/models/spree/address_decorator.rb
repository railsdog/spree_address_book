Spree::Address.class_eval do
  attr_accessor :address_type

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
    except_list = ['id', 'updated_at', 'created_at']
    except_list << 'alternative_phone' unless Spree::Config[:alternative_shipping_phone]
    except_list << 'company' unless Spree::Config[:company]

    a = attributes.except(*except_list)
    a.each{|k, v|
      a[k] = v.downcase.strip.gsub(/\s+/, ' ') if v.is_a?(String)
    }
    a['state_name'] = nil if a['state_name'].blank?
    a
  end

  # can modify an address if it's not been used in an completed order
  # Users of the gem can override this method to provide different rules.
  def editable?
    new_record? || !Spree::Order.complete.where("bill_address_id = ? OR ship_address_id = ?", self.id, self.id).exists?
  end

  def can_be_deleted?
    shipments.empty? && Spree::Order.where("bill_address_id = ? OR ship_address_id = ?", self.id, self.id).count == 0
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
    if can_be_deleted?
      super
    else
      update_column :deleted_at, Time.now
    end
  end

  private
  def h(str)
    (str ? CGI::escapeHTML(str.to_s) : str).try(:html_safe)
  end
end
