# Adds @addresses to the users controller so the address list can be embedded
# on the user's account details page.
Spree::Admin::UsersController.class_eval do
  include Spree::AddressUpdateHelper

  before_filter :load_address_list

  # UPDATE WITH SPREE
  # Changed `render :edit` to `redirect_to edit_admin_user_path(@user)`
  # Changed flash translation
  # Removed bill address params if the main params are blank
  def create
    if params[:user]
      roles = params[:user].delete("spree_role_ids")

      # Don't try to create a billing address if it was left blank
      addr = params[:user][:bill_address_attributes]
      if addr
        if addr[:firstname].blank? && addr[:lastname].blank? && addr[:address1].blank?
          params[:user].delete(:bill_address_attributes)
        end
      end
    end

    @user = Spree.user_class.new(user_params)
    if @user.save

      if roles
        @user.spree_roles = roles.reject(&:blank?).collect{|r| Spree::Role.find(r)}
      end

      flash[:success] = Spree.t(:successfully_created, resource: @user.class.model_name.human)
      redirect_to edit_admin_user_path(@user)
    else
      render :new
    end
  end

  private
  def load_address_list
    @addresses = get_address_list(nil, @user)
  end
end
