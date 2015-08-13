module Spree::AddressUpdateHelper
  # Returns params, requiring/permitting address-related parameters.
  def address_params
    params.require(:address).permit(Spree::PermittedAttributes.address_attributes)
  end

  # For use by #update actions of address controllers.  Pass the existing
  # @address for +address+, and a deduplicated address list for +addresses+.
  # Returns the modified address, which may not be the object that was passed
  # in, and the matching Spree::AddressBookGroups for the new and old address
  # data, if present.
  #
  # Example:
  #   address, new_match, old_match = update_and_merge(@address, @addresses)
  def update_and_merge(address, addresses)
    if !address.editable? # FIXME: Should not happen via UI unless order has detached address not on user
      address.errors.add(:base, I18n.t(:address_not_editable, scope: [:address_book]))
      return address
    end

    user = address.user
    new_address = address.clone
    new_address.attributes = address_params
    new_match = addresses.find(new_address)
    old_match = addresses.find(address)

    attrs = address_params

    if new_match && new_match != old_match
      puts "  \e[33mNew match: id=#{address.id.inspect} new=#{new_match.try(:id).inspect} old=#{old_match.try(:id).inspect}\e[0m" # XXX

      # The new address data matches a group, the existing data potentially
      # matches a different group.  Need to destroy the old group, deduplicate
      # and modify the new group, and reassign default addresses as needed.
      address = new_match.primary_address

      # Destroy any old matching addresses, if possible.
      old_match.destroy if old_match

      # Update any remaining editable addresses.
      old_match.update_all_attributes(attrs) if old_match
      new_match.update_all_attributes(attrs)
    elsif old_match
      puts "  \e[33mOld match: id=#{address.id.inspect} new=#{new_match.try(:id).inspect} old=#{old_match.try(:id).inspect}\e[0m" # XXX

      # The old address data matches a group, the new data is identical or does
      # not match a group.  Need to update the existing addresses with the new
      # data and deduplicate.
      address = old_match.primary_address

      # Deduplicate and update the existing addresses.
      old_match.destroy_duplicates
      old_match.update_all_attributes(attrs)
    else
      puts "  \e[1;32mNO match: id=#{address.id}\e[0m" # XXX

      # No matching group; just update the address and rely on order and user
      # callbacks to synchronize addresses.
      address.update_attributes(attrs)
    end

    # Update default address assignments in case they were destroyed
    if address.user_id && user && address.user_id == user.id
      user.bill_address_id = address.id if new_match.try(:user_bill) || old_match.try(:user_bill)
      user.ship_address_id = address.id if new_match.try(:user_ship) || old_match.try(:user_ship)

      if user.changed? && !user.save
        address.errors.add(:user, user.errors.full_messages.to_sentence)
      end
    end

    return address, new_match, old_match
  end
end
