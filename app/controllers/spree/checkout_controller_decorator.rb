Spree::CheckoutController.class_eval do
  helper Spree::AddressesHelper
  helper_method :get_selected_addresses

  before_filter :get_address_list
  before_filter :set_address_params, :only => :update


  protected

  # Sets or re-sets @@addresses to a deduplicated address list for the order
  # and user.
  def get_address_list
    if spree_current_user
      @addresses = Spree::AddressBookList.new(spree_current_user, @order)
    else
      @addresses = Spree::AddressBookList.new(@order)
    end
  end

  # Sets the billing and shipping address that should be highlighted on the
  # checkout address form in @bill_address and @ship_address.  Gives first
  # priority to an unsaved address on the order, then to a saved address
  # attached to the order, then to the user's default address.  Returns the
  # billing and shipping address.
  #
  # Although it's ugly, this gets called from within the view since it needs to
  # happen after the order is updated but before the view is rendered.
  #
  # TODO: Figure out a better way, perhaps by moving logic into the order model
  def get_selected_addresses
    get_address_list # Update @addresses in case addresses were set by #update

    if @order.bill_address.present? && @order.bill_address_id.nil?
      @bill_address = @order.bill_address
    elsif @addresses.order_bill
      @bill_address = @addresses.order_bill
    elsif @addresses.user_bill
      @bill_address = @addresses.user_bill
    else
      @bill_address = @addresses.first
    end

    if @order.ship_address.present? && @order.ship_address_id.nil?
      @ship_address = @order.ship_address
    elsif @addresses.order_ship
      @ship_address = @addresses.order_ship
    elsif @addresses.user_ship
      @ship_address = @addresses.user_ship
    else
      @ship_address = @addresses.first
    end

    return @bill_address, @ship_address
  end

  # Changes address parameters to prevent duplicate addresses.
  def set_address_params
    return unless params[:order] && params[:state] == "address"

    check_address(:ship)
    check_address(:bill)
  end

  # Retrieves and checks an address by ID or by attributes for the given +type+
  # (:ship or :bill), then updates params accordingly.
  #
  # TODO: This would probably be better off in a Spree::Order decorator
  def check_address(type)
    if type == :ship
      id_name = :ship_address_id
      attr_name = :ship_address_attributes
    else
      id_name = :bill_address_id
      attr_name = :bill_address_attributes
    end

    if params[:order][id_name].to_i > 0
      # Using an existing address by ID
      params[:order].delete(attr_name)
      find_address(params[:order][id_name].to_i)
    else
      # Using the address form to enter a new address
      params[:order].delete(id_name)

      # Check for an existing matching address, replace form data with its id if found
      if spree_current_user && params[:order][attr_name]
        addr = Spree::Address.new(
          params[:order][attr_name].permit(permitted_address_attributes).merge(
            alternative_phone: params[:order][attr_name][:phone],
            user_id: spree_current_user.id
          )
        )

        if @addresses.is_a?(Spree::AddressBookList)
          a = @addresses.find(addr)
          if a
            params[:order][id_name] = a.id
            params[:order].delete(attr_name)
          end
        end
      end
    end
  end

  # Finds the given address and makes sure it's owned by the current user or
  # attached to the current guest order.
  def find_address(id)
    unless spree_current_user || @order.bill_address_id == id || @order.ship_address_id == id
      raise 'Guests should not be able to choose checkout addresses by ID'
    end

    addr = Spree::Address.find(id)

    if addr.user_id != spree_current_user.try(:id)
      raise "Frontend address forging: address user #{addr.user_id.inspect} != current user #{spree_current_user.try(:id).inspect}"
    end

    addr
  end
end
