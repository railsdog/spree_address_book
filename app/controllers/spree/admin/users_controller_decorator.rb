# Adds @addresses to the users controller so the address list can be embedded
# on the user's account details page.
Spree::Admin::UsersController.class_eval do
  include Spree::AddressUpdateHelper

  before_filter :load_address_list

  # UPDATE WITH SPREE (modified to change render :edit to redirect_to)
  def create
    if params[:user]
      roles = params[:user].delete("spree_role_ids")
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
