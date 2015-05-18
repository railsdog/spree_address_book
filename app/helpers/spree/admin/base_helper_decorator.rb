Spree::Admin::BaseHelper.class_eval do
  def compare_addresses(address1, address2)
    return false unless address1 and address2
    addresses = [address1, address2]
    addresses = addresses.map {|a| a.dup.attributes.merge!("user_id" => nil) }
    addresses.first == addresses.last
  end
end
