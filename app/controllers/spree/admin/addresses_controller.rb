module Spree
  module Admin
    class AddressesController < ResourceController
      before_filter :find_address, only: [:edit, :update, :destroy]
      before_filter :set_user_or_order

      def index
        if @order and @user
          # Non-guest order
          @addresses = Spree::AddressBookList.new(@user, @order)
        elsif @order
          # Guest order
          @addresses = Spree::AddressBookList.new(@order)
        else
          # User account
          @addresses = Spree::AddressBookList.new(@user)
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
          # TODO: There might be a better way to figure out where to assign the address
          if @order and !@user
            case params[:address][:address_type]
            when "bill_address"
              @order.bill_address = @address
            when "ship_address"
              @order.ship_address = @address
            end
            @order.save!
          end

          flash[:success] = Spree.t(:account_updated)

          redirect_to admin_addresses_path(user_id: @user.try(:id), order_id: @order.try(:id))
        else
          flash[:error] = @address.errors.full_messages.to_sentence
          render :new
        end
      end

      def edit
        if @order and !@user
          # Guest order; limit to the order's addresses
          @address = @order.addresses.select{|r| r.id == params[:id].to_i }.first
        end
      end

      def update
        list_path = admin_addresses_path(
          user_id: @user.try(:id) || @address.user_id || @order.try(:user_id), order_id: @order.try(:id)
        )

        if !@address.editable?
          flash[:error] = I18n.t(:address_not_editable, scope: [:address_book])
          redirect_to list_path
        elsif @address.update_attributes(address_params)
          flash[:success] = Spree.t(:account_updated)
          redirect_to list_path
        else
          flash[:error] = @address.errors.full_messages.to_sentence
          render :edit
        end
      end

      def destroy
        if @address.destroy
          flash[:success] = Spree.t(:account_updated)
        else
          flash[:error] = @address.errors.full_messages.to_sentence
        end

        redirect_to admin_addresses_path(user_id: @user.try(:id), order_id: @order.try(:id))
      end

      def update_addresses
        if @order and !@user
          unless @order.update_attributes(params[:order].permit(:bill_address_id, :ship_address_id))
            flash[:error] = @order.errors.full_messages.to_sentence
          end
        elsif @user
          if @user.update_attributes(params[:user].permit(:bill_address_id, :ship_address_id))
            update_order_addresses
          else
            flash[:error] = @order.errors.full_messages.to_sentence
          end
        end

        flash[:success] = I18n.t(:default_addresses_updated, scope: :address_book) unless flash[:error]
        redirect_to admin_addresses_path(user_id: @user.try(:id), order_id: @order.try(:id))
      end

      private
        def address_params
          params.require(:address).permit(PermittedAttributes.address_attributes)
        end

        def find_address
          @address ||= Spree::Address.find(params[:id]) if params[:id]
        end

        def set_user_or_order
          @user ||= Spree::User.find(params[:user_id]) if params[:user_id]
          @order ||= Spree::Order.find(params[:order_id]) if params[:order_id]
          @user ||= @order.user if @order

          if @order && @user && @user != @order.user
            raise "User ID does not match order's user ID!"
          end
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
