Spree::CheckoutController.class_eval do
  helper Spree::AddressesHelper

  after_filter :normalize_addresses, :only => :update
  before_filter :set_addresses, :only => :update

  protected

  def set_addresses
    return unless params[:order] && params[:state] == "address"

    check_address(:ship)
    check_address(:bill)
  end

  # Retrieves and checks an address by ID or by attributes for the given +type+
  # (:ship or :bill).
  def check_address(type)
    if type == :ship
      id_name = :ship_address_id
      attr_name = :ship_address_attributes
    else
      id_name = :bill_address_id
      attr_name = :bill_address_attributes
    end

    if params[:order][id_name].to_i > 0
      params[:order].delete(attr_name)
      find_address(params[:order][id_name])
    else
      params[:order].delete(id_name)

      # Check for an existing matching address
      if spree_current_user && params[:order][attr_name]
        addr = Spree::Address.new(
          params[:order][attr_name].permit(permitted_address_attributes).merge(
            alternative_phone: params[:order][attr_name][:phone],
            user_id: spree_current_user.id
          )
        )
        spree_current_user.addresses.each do |a|
          if a.same_as?(addr)
            params[:order][id_name] = a.id
            params[:order].delete(attr_name)
            break
          end
        end
      end
    end
  end

  # Finds the given address and makes sure it's owned by the current user.
  def find_address(id)
    addr = Spree::Address.find(id)

    # FIXME: What about guests?  Can guests use non-user address IDs from other orders?
    if addr.user_id != spree_current_user.id
      raise "Frontend address forging: address user #{addr.user_id} != current user #{spree_current_user.id}"
    end

    addr
  end

  def normalize_addresses
    return unless params[:state] == "address" && @order.bill_address_id && @order.ship_address_id

    # ensure that there is no validation errors and addresses were saved
    return unless @order.bill_address && @order.ship_address

    bill_address = @order.bill_address
    ship_address = @order.ship_address
    if @order.bill_address_id != @order.ship_address_id && bill_address.same_as?(ship_address)
      @order.update_column(:bill_address_id, ship_address.id)
      bill_address.destroy
    else
      bill_address.update_attribute(:user_id, spree_current_user.try(:id))
    end

    ship_address.update_attribute(:user_id, spree_current_user.try(:id))
  end
end
