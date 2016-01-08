module SpreeAddressManagement
  module TestingSupport
    module AddressHelpers
      # Fill in an already loaded address form with the given +values+ (either a
      # Spree::Address, or a Hash mapping field names to field values).
      #
      # For frontend forms, +type+ can optionally be :bill to fill in the
      # billing address, or :ship to fill in the shipping address.  The Other
      # Address radio button and Use Billing Address checkbox will be set
      # appropriately, if needed.  For admin forms, if +type+ is :user, :bill,
      # or :ship, then the address type field (for order addresses) will be set
      # to User, Billing, or Shipping, respectively (see #assign_order_address
      # in Spree::Admin::AddressesController).
      #
      # Note that JavaScript is required to fill in the state field.
      def fill_in_address(values, type=nil)
        if type
          if current_path.start_with?(spree.admin_path)
            # Admin forms
            expect(page).to have_css('#address_address_type')

            if type == :user
              select Spree.t(:user), from: Spree.t(:address_type)
            elsif type == :bill
              select Spree.t(:billing_address), from: Spree.t(:address_type)
            elsif type == :ship
              select Spree.t(:shipping_address), from: Spree.t(:address_type)
            else
              raise "Invalid type #{type.inspect}"
            end
          elsif current_path.start_with?(spree.checkout_path)
            # Checkout forms
            if type == :bill
              container = '#billing'
            elsif type == :ship
              container = '#shipping'
            end
          else
            # TODO: Frontend account forms, if needed
          end
        end

        if container
          within(container) do
            fill_in_address_fields(values)
          end
        else
          fill_in_address_fields(values)
        end
      end

      private

      # Fills in an address form as does #fill_in_address, but does not choose
      # "Other address", limit scope using #within, etc.
      def fill_in_address_fields(values)
        uncheck 'order_use_billing' if page.has_css?('#order_use_billing')

        if page.has_css?('#order_bill_address_id_0, #order_ship_address_id_0')
          choose I18n.t(:other_address, scope: :address_book)
        end

        if values.is_a?(Spree::Address)
          fill_in Spree.t(:first_name), with: values.firstname
          fill_in Spree.t(:last_name), with: values.lastname
          fill_in Spree.t(:company), with: values.company if Spree::Config[:company]

          if page.has_content?(/#{Regexp.escape(Spree.t(:street_address_2))}/i)
            fill_in Spree.t(:street_address), with: values.address1
            fill_in Spree.t(:street_address_2), with: values.address2
          else
            fill_in Spree.t(:address1), with: values.address1
            fill_in Spree.t(:address2), with: values.address2
          end

          select values.country.name, from: Spree.t(:country) if values.country
          fill_in Spree.t(:city), with: values.city
          fill_in Spree.t(:zipcode), with: values.zipcode
          select values.state.name, from: Spree.t(:state)
          fill_in Spree.t(:phone), with: values.phone
          fill_in Spree.t(:alternative_phone), with: values.alternative_phone if Spree::Config[:alternative_shipping_phone]
        elsif values.is_a?(Hash)
          values.each do |k, v|
            if k == Spree.t(:country) || k == Spree.t(:state)
              select v, from: k
            else
              fill_in k, with: v
            end
          end
        else
          raise "Invalid class #{values.class.name} for values"
        end
      end
    end
  end
end

RSpec.configure do |config|
  config.include SpreeAddressManagement::TestingSupport::AddressHelpers, type: :feature
end
