module Spree
  module Admin
    class AddressesController < ResourceController
      before_filter :set_user, only: [:index, :new, :create, :edit, :update, :update_addresses]

      def index
        @user_addresses = @user.addresses.order('created_at DESC')
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
      end

      def edit
        @address = @user.addresses.find(params[:id])
      end

      def update
        @address = Spree::Address.find(params[:id])
        if @address.update_attributes(address_params)
          flash.now[:success] = Spree.t(:account_updated)
        end
      end

      def destroy
        @address = Spree::Address.find(params[:id])
        if @address.destroy
          flash.now[:success] = Spree.t(:account_updated)
        end
      end

      def update_addresses
        @user.update_attributes(params[:user].permit(:bill_address_id, :ship_address_id))
        flash[:success] = Spree.t(:default_addresses_updated)
        redirect_to admin_addresses_path(user_id: @user)
      end

      private
        def address_params
          params.require(:address).permit(PermittedAttributes.address_attributes)
        end

        def set_user
          @user ||= Spree::User.find(params[:user_id])
        end
    end
  end
end
