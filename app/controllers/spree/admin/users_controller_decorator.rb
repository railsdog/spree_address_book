Spree::Admin::UsersController.class_eval do
  before_filter :build_user_addresses_hash, only: [:addresses, :edit_address]

  def addresses
    # if request.put?
    #   if @user.update_attributes(user_params)
    #     flash.now[:success] = Spree.t(:account_updated)
    #   end

    #   render :addresses
    # end
  end

  # Update with Spree 2-3-stable
  def edit_address
    @address = @user.addresses.find(params[:address_id])
    redirect_to admin_users_addresses_path unless @address
    if request.put?
      if @user.update_attributes(user_params)
        flash.now[:success] = Spree.t(:account_updated)
      end

      redirect_to addresses_admin_user_path(@user)
    end
  end

  def update_addresses
    @user = model_class.find(params[:user_id])
    @user.update_attributes(params[:user].permit(:bill_address_id, :ship_address_id))
    flash[:success] = Spree.t(:default_addresses_updated)
    redirect_to addresses_admin_user_path(@user)
  end

  private
    def build_user_addresses_hash
      @user ||= model_class.find(params[:user_id])
      @order = @user.orders.last

      @user_addresses = @user.addresses
    end
end
