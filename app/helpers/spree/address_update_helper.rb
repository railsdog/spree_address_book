module Spree::AddressUpdateHelper
  # Saves request.referrer into session['spree_user_return_to'] for use by
  # Spree's #redirect_back_or_default method.
  def save_referrer
    session['spree_user_return_to'] = request.referrer 
  end

  # Returns params, requiring/permitting address-related parameters.
  def address_params
    @addr_attrs ||= params.require(:address).permit(Spree::PermittedAttributes.address_attributes)
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
    if !address.editable? # Should not happen via UI unless order has detached address not on user
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
      # The new address data matches a group, the existing data potentially
      # matches a different group.  Need to destroy the old group, deduplicate
      # and modify the new group, and reassign default addresses as needed.
      address = new_match.primary_address

      # Destroy any old matching addresses, if possible.
      old_match.destroy if old_match
      new_match.destroy_duplicates

      # Update any remaining editable addresses.
      old_match.update_all_attributes(attrs) if old_match
      new_match.update_all_attributes(attrs)
    elsif old_match
      # The old address data matches a group, the new data is identical or does
      # not match a group.  Need to update the existing addresses with the new
      # data and deduplicate.
      address = old_match.primary_address

      # Deduplicate and update the existing addresses.
      old_match.destroy_duplicates
      old_match.update_all_attributes(attrs)
    else
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

  # Assigns addresses for the @user if params[:user] is set and @order if
  # params[:order] is set.  Returns true on success, false on error, and sets
  # the error and success flashes appropriately.
  def update_address_selection
    errors = []

    if @user
      update_object_addresses(@user, params[:user])
      errors.concat @user.errors.full_messages
    end

    if @order
      update_object_addresses(@order, params[:order])
      errors.concat @order.errors.full_messages
    end

    if errors.any?
      flash[:error] = (@user.try(:errors).try(:full_messages) + @order.errors.full_messages).to_sentence
      false
    else
      flash[:success] = I18n.t(:default_addresses_updated, scope: :address_book)
      true
    end
  end

  # Assigns address IDs from +attrs+ (an ActionController::Parameters instance)
  # to the given +object+ (an order or user).  Callbacks on the order decorator
  # will ensure that addresses are deduplicated.  Does nothing and adds errors
  # to the object if the object's #can_update_addresses? method returns false.
  #
  # For use by address assignment actions of address controllers.  Use .errors
  # instead of .valid? to check for errors on the object afterward.
  def update_object_addresses(object, attrs)
    if attrs
      attrs = attrs.permit(:bill_address_id, :ship_address_id)

      bill_id = attrs[:bill_address_id]
      ship_id = attrs[:ship_address_id]

      # Do nothing except save the object if the IDs are unchanged.
      if bill_id == object.bill_address_id && ship_id == object.ship_address_id
        object.save
      else
        unless object.can_update_addresses?
          object.save
          object.errors.add(:base, Spree.t(:addresses_not_editable, resource: object.class.model_name.human))
          false
        else
          bill = Spree::Address.find_by_id(bill_id)
          ship = Spree::Address.find_by_id(ship_id)

          if bill && bill.user_id && @user && bill.user_id != @user.id
            raise 'Bill address belongs to a different user'
          end

          if ship && ship.user_id && @user && ship.user_id != @user.id
            raise 'Ship address belongs to a different user'
          end

          object.bill_address_id = bill.id if bill
          object.ship_address_id = ship.id if ship

          object.save
        end
      end
    end
  end

  # Returns a Spree::AddressBookList for the given order and user, both of
  # which may be nil.
  def get_address_list(order, user)
    if @order and @user
      # Non-guest order
      Spree::AddressBookList.new(@user, @order)
    elsif @order
      # Guest order
      Spree::AddressBookList.new(@order)
    elsif @user
      # User account
      Spree::AddressBookList.new(@user)
    else
      # Nothing; return a blank list
      Spree::AddressBookList.new(nil)
    end
  end
end
