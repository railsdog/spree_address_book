Spree::CheckoutController.class_eval do
  helper Spree::AddressesHelper

  before_filter :get_address_list
  before_filter :set_addresses, :only => :update

  protected

  def get_address_list
    @addresses = spree_current_user && Spree::AddressBookList.new(spree_current_user)
  end

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

  # Finds the given address and makes sure it's owned by the current user.
  def find_address(id)
    raise 'Guests should not be able to choose checkout addresses by ID' unless spree_current_user

    addr = Spree::Address.find(id)

    if addr.user_id != spree_current_user.try(:id)
      raise "Frontend address forging: address user #{addr.user_id.inspect} != current user #{spree_current_user.try(:id).inspect}"
    end

    addr
  end
end
