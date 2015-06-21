module Spree
  module Admin
    class AddressesController < ResourceController
      before_filter :set_user_or_order

      def index
        if @order and @user
          @addresses = @user.user_and_order_addresses(@order).sort_by(&:'created_at')
        elsif @user
          @addresses = @user.addresses.order('created_at DESC')
        else
          @addresses = @order.addresses.sort_by(&:'created_at')
        end
      end

      def new
        country_id = Spree::Address.default.country.id
        @address = Spree::Address.new(:country_id => country_id, user: @user)
      end

      def create
        country_id = Spree::Address.default.country.id
        @address = Spree::Address.new({:country_id => country_id, user: @user}.merge(params[:address]))
        if @address.save
          if @order and !@user
            case params[:address][:address_type]
            when "bill_address"
              @order.bill_address = @address
            when "ship_address"
              @order.ship_address = @address
            end
            @order.save!
          end
          flash.now[:success] = Spree.t(:account_updated)
        end
        redirect_to admin_addresses_path(user_id: @user.try(:id), order_id: @order.try(:id))
      end

      def edit
        if @order and !@user
          @address = @order.addresses.select{|r| r.id == params[:id].to_i }.first
        else
          @address = @user.addresses.find(params[:id])
        end
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
        if @order and !@user
          @order.update_attributes(params[:order].permit(:bill_address_id, :ship_address_id))
        elsif @user
          @user.update_attributes(params[:user].permit(:bill_address_id, :ship_address_id))
          update_order_addresses
        end
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

        def update_order_addresses
          if params[:order]
            params[:order].permit(:bill_address_id, :ship_address_id)
            bill_address = Spree::Address.find(params[:order][:bill_address_id])
            ship_address = Spree::Address.find(params[:order][:ship_address_id])
            if bill_address
              @order.bill_address_attributes = bill_address.dup.attributes
            end
            if ship_address
              @order.ship_address_attributes = ship_address.dup.attributes
            end
            @order.save
          end
        end
    end
  end
end
