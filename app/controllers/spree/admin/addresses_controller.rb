module Spree
  module Admin
    class AddressesController < ResourceController
      before_filter :set_user_or_order

      def index
        if @order
          @addresses = @user.user_and_order_addresses(@order).sort_by(&:'created_at')
        else
          @addresses = @user.addresses.order('created_at DESC')
        end
      end

      def new
        country_id = Spree::Address.default.country.id
        @address = @user.addresses.new(:country_id => country_id)
      end

      def create
        @address = @user.addresses.new(address_params)
        if @address.save
          flash.now[:success] = Spree.t(:account_updated)
        end
        redirect_to admin_addresses_path(user_id: @user.try(:id), order_id: @order.try(:id))
      end

      def edit
        @address = @user.addresses.find(params[:id])
      end

      def update
        @address = Spree::Address.find(params[:id])
        if @address.update_attributes(address_params)
          flash.now[:success] = Spree.t(:account_updated)
        end
        redirect_to admin_addresses_path(user_id: @user.try(:id), order_id: @order.try(:id))
      end

      def destroy
        @address = Spree::Address.find(params[:id])
        if @address.destroy
          flash.now[:success] = Spree.t(:account_updated)
        end
        redirect_to admin_addresses_path(user_id: @user.try(:id), order_id: @order.try(:id))
      end

      def update_addresses
        @user.update_attributes(params[:user].permit(:bill_address_id, :ship_address_id))
        @order.update_attributes(params[:order].permit(:bill_address_id, :ship_address_id)) if params[:order]
        flash[:success] = Spree.t(:default_addresses_updated)
        redirect_to admin_addresses_path(user_id: @user.try(:id), order_id: @order.try(:id))
      end

      def redirect_back
        redirect_to edit_admin_order_path(Spree::Order.find(params[:order_id])) if params[:order_id]
        redirect_to edit_admin_user_path(Spree.user_class.find(params[:user_id])) if params[:user_id]
      end

      private
        def address_params
          params.require(:address).permit(PermittedAttributes.address_attributes)
        end

        def set_user_or_order
          @user ||= Spree::User.find(params[:user_id]) if params[:user_id]
          @order ||= Spree::Order.find(params[:order_id]) if params[:order_id]
          @user ||= @order.user if @order
        end
    end
  end
end
