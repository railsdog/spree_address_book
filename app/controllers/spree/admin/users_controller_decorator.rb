Spree::Admin::UsersController.class_eval do
  before_filter :build_user_addresses_hash, only: [:addresses, :edit_address]

  def addresses
    # => Original action is below
    # => Alias method is now edit_address
    #
    # if request.put?
    #   if @user.update_attributes(user_params)
    #     flash.now[:success] = Spree.t(:account_updated)
    #   end

    #   render :addresses
    # end
  end

  # Update with Spree 2-3-stable
  def edit_address
    @user = model_class.find(params[:user_id])
    @address = @user.addresses.find(params[:address_id])
    redirect_to admin_users_addresses_path unless @address
    if request.put?
      if @user.update_attributes(user_params)
        flash.now[:success] = Spree.t(:account_updated)
      end

      redirect_to addresses_admin_user_path(@user)
    end
  end

  private
    def build_user_addresses_hash
      @user ||= model_class.find(params[:user_id])
      @order = @user.orders.last

      @user_addresses = {}

      @user_addresses[I18n.t(:billing_address_type, scope: :address_book)] = [
        @user.try(:bill_address),
        @order.try(:bill_address)
      ].uniq.compact

      @user_addresses[I18n.t(:shipping_address_type, scope: :address_book)] = [
        @user.try(:ship_address),
        @order.try(:ship_address)
      ].uniq.compact
    end
end
