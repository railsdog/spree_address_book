module FrontendAddresses
  # Fills in a frontend checkout or user account address form.  Wrap with
  # within('#shipping') or within('#billing') to fill out a specific address
  # type during checkout.
  def fill_in_address(address)
    fill_in Spree.t(:first_name), :with => address.firstname
    fill_in "Last Name", :with => address.lastname
    fill_in "Company", :with => address.company if Spree::Config[:company]
    fill_in Spree.t(:address1), :with => address.address1
    fill_in Spree.t(:address2), :with => address.address2
    select address.state.name, :from => Spree.t(:state)
    fill_in Spree.t(:city), :with => address.city
    fill_in Spree.t(:zip), :with => address.zipcode
    fill_in Spree.t(:phone), :with => address.phone
    fill_in Spree.t(:alternative_phone), :with => address.alternative_phone if Spree::Config[:alternative_shipping_phone]
  end
end

RSpec.configure do |c|
  c.include FrontendAddresses
end
