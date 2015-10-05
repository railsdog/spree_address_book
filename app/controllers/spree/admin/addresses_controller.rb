module Spree
  module Admin
    class AddressesController < ResourceController
      helper Spree::AddressesHelper
      include Spree::AddressUpdateHelper

      before_filter :set_user_or_order
      before_filter :load_address_list
      before_filter :find_address, only: [:edit, :update, :destroy]

      before_action :save_referrer, only: [:new, :edit, :destroy] # TODO: use redirect_to :back instead?

      # TODO: Get rid of this action, since the generic addresses list is no longer used.
      def redirect_back
        redirect_to collection_url
      end

      def new
        unless @order.try(:can_update_addresses?) || @user.try(:can_update_addresses?)
          flash[:error] = Spree.t(:addresses_not_editable, resource: (@user || @order).try(:class).try(:model_name).try(:human))
          redirect_back_or_default(collection_url)
          return
        end

        country_id = Spree::Address.default.country.id
        @address = Spree::Address.new(:country_id => country_id, user: @user)
      end

      def create
        country_id = Spree::Address.default.country.id
        @address = Spree::Address.new({ country_id: country_id, user: @user }.merge!(address_params))

        # Don't allow creating duplicate addresses on a user or guest order
        match = @addresses.find(@address)
        if match
          match.destroy_duplicates
          match.update_all_attributes(address_params)
          @address = match.primary_address
        end

        if @address.save
          assign_order_address if @order
        end

        errors = []
        errors.concat @address.errors.full_messages

        if @order
          errors.concat @order.errors.full_messages
          errors.concat @order.bill_address.errors.full_messages if @order.bill_address
          errors.concat @order.ship_address.errors.full_messages if @order.ship_address
        end

        if errors.any?
          flash[:error] = errors.uniq.to_sentence
          render :new
        else
          flash[:success] = Spree.t(:successfully_created, resource: @address.class.model_name.human)
          redirect_back_or_default(collection_url)
        end
      end

      def edit
        if !@address.editable?
          flash[:error] = I18n.t(:address_not_editable, scope: [:address_book])
          redirect_back_or_default(collection_url)
          return
        end
      end

      def update
        @address, new_match, old_match = update_and_merge(@address, @addresses)

        assign_order_address if @order && @address.errors.empty?

        if @address.errors.any?
          flash[:error] = @address.errors.full_messages.uniq.to_sentence
          render :edit
        else
          flash[:success] = Spree.t(:successfully_updated, resource: @address.class.model_name.human)
          redirect_back_or_default(collection_url)
        end
      end

      def destroy
        a = @addresses.find(@address) || @address

        if a.destroy
          flash[:success] = Spree.t(:successfully_removed, resource: @address.class.model_name.human)
        else
          flash[:error] = @address.errors.full_messages.to_sentence
        end

        redirect_back_or_default(collection_url) unless request.xhr?
      end

      def update_addresses
        update_address_selection
        redirect_to :back unless request.xhr?
      end

      # Override #unauthorized from spree_auth_devise to prevent XHR responses
      # from including layout HTML if authorization fails.
      if method_defined?(:unauthorized)
        def unauthorized_with_address_xhr
          if request.xhr?
            response.status = 401
            render html: Spree.t(:authorization_failure), status: 401
          else
            unauthorized_without_address_xhr
          end
        end
        alias_method_chain :unauthorized, :address_xhr
      end

      protected
        # Override Spree::Admin::ResourceController#collection_url to include user_id and order_id.
        def collection_url(options={})
          order_id = options[:order_id] || @order.try(:id) || params[:order_id]
          user_id = options[:user_id] || @user.try(:id) || params[:user_id]

          # TODO: Use more "resourceful" routing under Order and/or User
          if order_id
            admin_order_customer_path(Spree::Order.find(order_id))
          elsif user_id
            edit_admin_user_path(Spree.user_class.find(user_id))
          else
            admin_path
          end
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

          authorize! action, @address if @address
        end

        # Load a deduplicated list of order and user addresses.
        def load_address_list
          @addresses = get_address_list(@order, @user)
        end

        def set_user_or_order
          @user ||= Spree::User.find(params[:user_id]) if params[:user_id]
          @order ||= Spree::Order.find(params[:order_id]) if params[:order_id]
          @user ||= @order.user if @order

          if @order && @user && @user != @order.user
            raise "User ID does not match order's user ID!"
          end

          authorize! :update, @user if @user
          authorize! :update, @order if @order

          if @order.nil? && @user.nil?
            flash[:error] = Spree.t(:no_resource_found, resource: 'order or user')
            redirect_to admin_path unless request.xhr?
          end
        end

        # Assigns a new or modified address to the order, if requested by the
        # user via the address type combobox.  Saves the order.  Use
        # @address.errors to detect any errors.
        def assign_order_address
          unless params[:address][:address_type]
            @order.save
          else
            unless @order.can_update_addresses?
              @order.save
              @address.errors.add(:order, Spree.t(:addresses_not_editable, resource: @order.class.model_name.human))
            else
              case params[:address][:address_type]
              when "bill_address"
                if @order.bill_address && !@order.bill_address.user && @order.bill_address.editable?
                  @order.bill_address.update_attributes(address_params)
                else
                  @order.bill_address = @address
                end

              when "ship_address"
                if @order.ship_address && !@order.ship_address.user && @order.ship_address.editable?
                  @order.ship_address.update_attributes(address_params)
                else
                  @order.ship_address = @address
                end
              end

              unless @order.save
                @address.errors.add(:order, @order.errors.full_messages.to_sentence)
              end
            end
          end
        end
    end
  end
end
