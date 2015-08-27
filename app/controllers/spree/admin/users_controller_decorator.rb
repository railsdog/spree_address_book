# Adds @addresses to the users controller so the address list can be embedded
# on the user's account details page.
Spree::Admin::UsersController.class_eval do
  include Spree::AddressUpdateHelper

  before_filter :load_address_list

  private
  def load_address_list
    @addresses = get_address_list(nil, @user)
  end
end
