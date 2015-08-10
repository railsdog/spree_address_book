# Represents a group of deduplicated addresses.  Could probably be optimized.
class Spree::AddressBookGroup
  # All unique addresses on the request, user, and order.
  attr_reader :addresses, :user_addresses, :order_addresses

  # Specifically assigned addresses.
  attr_reader :user_ship, :user_bill, :order_ship, :order_bill

  # The address object to use to represent all grouped addresses.
  attr_reader :primary_address

  delegate :count, :each, :[], to: :addresses
  delegate :id, :user_id, :created_at, :updated_at, :to_s, :same_as?, :comparison_attributes, :clone_without_user,
    to: :primary_address, allow_nil: true


  # Initializes an address group for the given +addresses+.  The +assignments+
  # parameter may be a Hash containing :order_bill, :order_ship, :user_bill,
  # and/or :user_ship, if any of the deduplicated addresses happen to be
  # assigned to their user or order's default addresses.  The +addresses+
  # parameter should be an Array containing addresses.  All addresses passed
  # here should have an ID in the database.
  def initialize(addresses, assignments=nil)
    raise 'Addresses must be an Array' unless addresses.is_a?(Array) # TODO: Accept ActiveRecord query?  Use multiple params?

    @user_addresses = addresses.select{|a| a.id && a.address1 && a.user.present? }
    @order_addresses = addresses.select{|a| a.id && a.address1 && a.user.nil? }

    if assignments.is_a?(Hash)
      assignments = assignments.select{|k, v| v.id && v.address1 }

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

  # Returns true if the +other+ address group has the same exact addresses as
  # this group.
  def ==(other)
    return false unless other.is_a?(Spree::AddressBookGroup)

    @addresses == other.addresses &&
      @order_addresses == other.order_addresses &&
      @user_addresses == other.user_addresses &&
      @user_ship == other.user_ship &&
      @user_bill == other.user_bill &&
      @order_ship == other.order_ship &&
      @order_bill == other.order_bill
  end

  # Destroys all editable user addresses in the group.
  def destroy
    result = true
    @user_addresses.each do |a|
      result &= a.destroy if a.editable?
    end
    @user_addresses.reject!(&:editable?)
    result
  end
end
