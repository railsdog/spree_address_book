module Spree
  module Admin
    class AddressesController < ResourceController
      helper Spree::AddressesHelper
      include Spree::AddressUpdateHelper

      before_filter :set_user_or_order
      before_filter :load_address_list
      before_filter :find_address, only: [:edit, :update, :destroy]

      def redirect_back
        if params[:order_id]
          redirect_to edit_admin_order_path(Spree::Order.find(params[:order_id]))
        elsif params[:user_id]
          redirect_to edit_admin_user_path(Spree.user_class.find(params[:user_id]))
        else
          redirect_to admin_path
        end
      end

      def new
        unless @order.try(:can_update_addresses?) || @user.try(:can_update_addresses?)
          flash[:error] = Spree.t(:addresses_not_editable, resource: (@user || @order).try(:class).try(:model_name).try(:human))
          redirect_to collection_url
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
          redirect_to collection_url
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
        uaddrcount(@user, "AAC:u:b4(aid=#{@address.try(:id).inspect})", order: @order) # XXX

        @address, new_match, old_match = update_and_merge(@address, @addresses)

        uaddrcount(@user, "AAC:u:mid(aid=#{@address.try(:id).inspect})", order: @order) # XXX


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

        assign_order_address if @order && @address.errors.empty?

        if @address.errors.any?
          flash[:error] = @address.errors.full_messages.uniq.to_sentence
          render :edit
        else
          flash[:success] = Spree.t(:successfully_updated, resource: @address.class.model_name.human)
          redirect_to collection_url
        end

        uaddrcount(@user, "AAC:u:aft(#{flash.to_hash})", order: @order) # XXX
      end

      def destroy
        a = @addresses.find(@address) || @address

        whereami("AAC:destroy:start(#{a.class}/#{a.id})") # XXX

        if a.destroy
          flash[:success] = Spree.t(:successfully_removed, resource: @address.class.model_name.human)
        else
          flash[:error] = @address.errors.full_messages.to_sentence
        end

        whereami("AAC:destroy:end(#{flash.to_hash})") # XXX

        redirect_to collection_url
      end

      def update_addresses
        uaddrcount(@user, "AAC:ua:b4", order: @order) # XXX

        update_address_selection
        redirect_to :back

        uaddrcount(@user, "AAC:ua:aft(#{flash.to_hash})", order: @order) # XXX
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

          authorize! action, @address if @address
        end

        # Load a deduplicated list of order and user addresses.
        def load_address_list
          @addresses = get_address_list(@order, @user)
        end

        def set_user_or_order
          whereami("AAC:suoo(#{params.to_hash}) U=#{@user.try(:id)} O=#{@order.try(:id)} ref=#{request.referrer}") # XXX

          @user ||= Spree::User.find(params[:user_id]) if params[:user_id]
          @order ||= Spree::Order.find(params[:order_id]) if params[:order_id]
          @user ||= @order.user if @order

          if @order && @user && @user != @order.user
            raise "User ID does not match order's user ID!"
          end

          authorize! action, @user if @user
          authorize! action, @order if @order

          if @order.nil? && @user.nil?
            flash[:error] = Spree.t(:no_resource_found, resource: 'order or user')
            redirect_to admin_path
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
