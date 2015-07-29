# Represents a group of deduplicated addresses.  Could probably be optimized.
class Spree::AddressBookGroup
  # All unique addresses on the request, user, and order.
  attr_reader :addresses, :user_addresses, :order_addresses

  # Specifically assigned addresses.  TODO: consider methods that return @primary_address as backup?
  attr_reader :user_ship, :user_bill, :order_ship, :order_bill

  # The address object to use to represent all grouped addresses.
  attr_reader :primary_address

  delegate :id, :updated_at, :to_s, to: :primary_address, allow_nil: true
  delegate :count, to: :addresses


  # Initializes an address group for the given +addresses+.  The +assignments+
  # parameter may be a Hash containing :order_bill, :order_ship, :user_bill,
  # and/or :user_ship, if any of the deduplicated addresses happen to be
  # assigned to their user or order's default addresses.  The +addresses+
  # parameter should be an Array containing addresses.  All addresses passed
  # here should have an ID in the database.
  def initialize(addresses, assignments=nil)
    raise 'Addresses must be an Array' unless addresses.is_a?(Array) # TODO: Accept ActiveRecord query?  Use multiple params?

    @user_addresses = addresses.select{|a| a.user.present?}
    @order_addresses = addresses.select{|a| a.user.nil?}

    if assignments.is_a?(Hash)
      if @user_ship = assignments[:user_ship]
        raise 'User shipping address should belong to a user' if @user_ship.user.nil?
        @user_addresses << @user_ship
      end

      if @user_bill = assignments[:user_bill]
        raise 'User billing address should belong to a user' if @user_bill.user.nil?
        @user_addresses << @user_bill
      end

      if @order_ship = assignments[:order_ship]
        @order_addresses << @order_ship
      end

      if @order_bill = assignments[:order_bill]
        @order_addresses << @order_bill
      end
    end

    if @user_addresses.any?{|a| a.user != @user_addresses.first.user}
      raise "Found addresses from multiple different users!"
    end

    @addresses = @user_addresses + @order_addresses

    if @addresses.any?{|a| !a.same_as?(@addresses.first) }
      raise 'Not all addresses are the same; only pass identical addresses (by #same_as?)'
    end

    [@user_addresses, @order_addresses, @addresses].each do |l|
      l.uniq!(&:id)
      l.sort_by!(&:updated_at)
      l.reverse!
    end

    if @order_addresses.count > 2
      raise 'Found more than two userless (order) addresses'
    end

    @primary_address = @user_addresses.first || @addresses.first
  end
end
