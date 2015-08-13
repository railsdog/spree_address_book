module Spree
  module Admin
    class AddressesController < ResourceController
      helper Spree::AddressesHelper
      include Spree::AddressUpdateHelper

      before_filter :set_user_or_order
      before_filter :get_address_list
      before_filter :find_address, only: [:edit, :update, :destroy]

      def new
        country_id = Spree::Address.default.country.id
        @address = Spree::Address.new(:country_id => country_id, user: @user)
      end

      def create
        country_id = Spree::Address.default.country.id
        @address = Spree::Address.new({:country_id => country_id, user: @user}.merge(params[:address]))

        # FIXME: Don't allow creating duplicate addresses on a user

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
        if !@address.editable?
          flash[:error] = I18n.t(:address_not_editable, scope: [:address_book])
          redirect_to collection_url
          return
        end
      end


      def update
        uaddrcount(@user, "AAC:u:b4", order: @order) # XXX

        @address, new_match, old_match = update_and_merge(@address, @addresses)

        uaddrcount(@user, "AAC:u:mid", order: @order) # XXX


        if new_match && old_match
          addrmatrix(new_match.addresses, old_match.addresses) # XXX
        end


        # XXX
        puts "    \e[35mAddress count: #{@addresses.try(:count).inspect}  New IDs: #{new_match.try(:addresses).try(:map, &:id).inspect}  Old IDs: #{old_match.try(:addresses).try(:map, &:id).inspect}\e[0m"
        #ap @new_match.try(:addresses)
        #ap @old_match.try(:addresses)
        #ap @addresses.try(:addresses).try(:map, &:addresses)
        ap @address
        ap params
        # XXX

        if @order
          # The order's before_validation #delink_addresses hook will take care
          # of assigning/cloning addresses, so just set the address IDs.
          @order.bill_address_id = @address.id if old_match.try(:order_bill) || new_match.try(:order_bill)
          @order.ship_address_id = @address.id if old_match.try(:order_ship) || new_match.try(:order_ship)

          # TODO: Do not reassign addresses on non-editable orders, do not
          # reassign addresses if the old address objects still exist

          if @order.changed? && !@order.save
            @address.errors.add(:order, @order.errors.full_messages.to_sentence)
          end
        end

        if @address.errors.any?
          flash[:error] = @address.errors.full_messages.uniq.to_sentence
          render :edit
        else
          flash[:success] = Spree.t(:account_updated)
          redirect_to collection_url
        end

        uaddrcount(@user, "AAC:u:aft(#{flash.to_hash})", order: @order) # XXX
      end

      def destroy
        a = @addresses.find(@address) || @address

        # Only destroys user and guest order addresses, not delinked order
        # addresses (FIXME?  Should it be possible to destroy an order
        # address?)
        if a.destroy
          flash[:success] = Spree.t(:account_updated)
        else
          flash[:error] = @address.errors.full_messages.to_sentence
        end

        redirect_to admin_addresses_path(user_id: @user.try(:id), order_id: @order.try(:id))
      end

      def update_addresses
        uaddrcount(@user, "AAC:ua:b4", order: @order) # XXX

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

        uaddrcount(@user, "AAC:ua:aft(#{flash.to_hash})", order: @order) # XXX

        flash[:success] = I18n.t(:default_addresses_updated, scope: :address_book) unless flash[:error]
        redirect_to admin_addresses_path(user_id: @user.try(:id), order_id: @order.try(:id))
      end

      protected
        # Override Spree::Admin::ResourceController#collection_url to include user_id and order_id.
        def collection_url(options={})
          # TODO: Use more "resourceful" routing under Order and/or User
          super({order_id: @order.try(:id), user_id: @user.try(:id)}.merge!(options))
        end

      private
        def find_address
          if @order && !@user
            # Guest order; limit to the order's addresses
            if @order.bill_address.try(:id) == params[:id].to_i
              @address = @order.bill_address
            elsif @order.ship_address.try(:id) == params[:id].to_i
              @address = @order.ship_address
            else
              # Trigger a 404
              raise ActiveRecord::RecordNotFound, "Could not find address #{params[:id].to_i} on order #{@order.number}"
            end
          else
            @address ||= Spree::Address.find(params[:id]) if params[:id]
          end

          if @user && @address.try(:user) && @user != @address.user
            raise "Address user does not match user being edited!"
          end
        end

        # Load a deduplicated list of order and user addresses.
        def get_address_list
          if @order and @user
            # Non-guest order
            @addresses = Spree::AddressBookList.new(@user, @order)
          elsif @order
            # Guest order
            @addresses = Spree::AddressBookList.new(@order)
          elsif @user
            # User account
            @addresses = Spree::AddressBookList.new(@user)
          else
            # Nothing; set a blank list
            @addresses = Spree::AddressBookList.new(nil)
          end
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
