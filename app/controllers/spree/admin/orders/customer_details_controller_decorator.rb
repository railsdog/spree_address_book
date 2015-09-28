# Adds @user and @addresses to the customer details controller so the address
# list can be embedded on the order's customer details page.
Spree::Admin::Orders::CustomerDetailsController.class_eval do
  include Spree::AddressUpdateHelper

  before_filter :set_user
  before_filter :load_address_list

  private
  def set_user
    if params[:user_id].present? && params[:user_id].to_i != @order.user_id
      @user = Spree::User.find(params[:user_id])
    end

    @user ||= @order.user

    if @order.user != @user
      raise "Given user and order's user do not match!"
    end
  end

  def load_address_list
    @addresses = get_address_list(@order, @user)
  end
end
