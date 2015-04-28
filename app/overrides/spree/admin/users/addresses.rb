Deface::Override.new(
  :virtual_path => "spree/admin/users/addresses",
  :name => "admin_user_addresses",
  :replace => "[data-hook='admin_user_addresses']",
  :partial => "spree/admin/users/address_book"
)
