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
        Rails.logger.warn 'BUG: User shipping address should belong to a user' if @user_ship.user.nil?
        @user_addresses << @user_ship
      end

      if @user_bill = assignments[:user_bill]
        Rails.logger.warn 'BUG: User billing address should belong to a user' if @user_bill.user.nil?
        @user_addresses << @user_bill
      end

      if @order_ship = assignments[:order_ship]
        @order_addresses << @order_ship
      end

      if @order_bill = assignments[:order_bill]
        @order_addresses << @order_bill
      end
    end

    user = @user_addresses.detect{|a| a.user_id }.try(:user)
    if user && @user_addresses.any?{|a| a.user_id && a.user != user }
      Rails.logger.error "Expected address user #{user.try(:id).inspect}, found users #{@user_addresses.map(&:user_id).uniq}"
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

  # Updates the attributes of every editable address in the group.  Returns
  # true on success or if there were no editable addresses, false on error.
  def update_all_attributes(attrs)
    puts "Calling all attributes: #{@addresses.map(&:id)}" # XXX

    result = true
    @addresses.each do |a|
      # XXX
      if a.editable?
        puts "Updating address #{a.try(:id).inspect}" # XXX
        result &= a.update_attributes(attrs) if a.editable?
      else
        puts "Skipping update of address #{a.try(:id).inspect}" # XXX
      end
    end
    result
  end

  # Destroys all editable user and deletable order addresses in the group.
  def destroy
    result = true

    @user_addresses.each do |a|
      next unless a.editable?
      result &= a.destroy
      @addresses.reject!{|addr| addr.id == a.id }
    end
    @user_addresses.reject!(&:editable?)

    @order_addresses.each do |a|
      next unless a.can_be_deleted?
      result &= a.destroy
      @addresses.reject!{|addr| addr.id == a.id }
    end
    @order_addresses.reject!(&:can_be_deleted?)

    result
  end

  # Destroys all editable duplicate user addresses in the group.
  def destroy_duplicates
    result = true

    puts "Before dedup: All=#{@addresses.map(&:id)} user=#{@user_addresses.map(&:id)} order=#{@order_addresses.map(&:id)}" # XXX

    primary_id = @primary_address.id
    @user_addresses.each do |a|
      next unless a.editable? && a.id != primary_id

      puts "\e[35mDestroying address \e[1m#{a.id}\e[0;35m from \e[1m#{@user_addresses.map(&:id)}\e[0;35m against primary \e[1m#{primary_id}\e[0m" # XXX
      puts "\t\e[31mUser: \e[1m#{a.user_id.inspect}/#{@primary_address.user_id.inspect}\e[0;31m Editable: \e[1m#{a.editable?}/#{@primary_address.editable?}\e[0m" # XXX

      Spree::Order.incomplete.with_address(a).each do |o|
        o.bill_address_id = primary_id if o.bill_address_id == a.id
        o.ship_address_id = primary_id if o.ship_address_id == a.id
        result &= o.save if o.changed?

        o.shipments.where(address_id: o.ship_address_id).update_all(address_id: primary_id)
      end

      result &= a.destroy
      @addresses.reject!{|addr| addr.id == a.id}
      puts "------------------ Removed address #{a.id} from @addresses" # XXX
    end
    @user_addresses.reject!{|a| a.editable? && a.id != @primary_address.id }

    puts "AFTER dedup: All=#{@addresses.map(&:id)} user=#{@user_addresses.map(&:id)} order=#{@order_addresses.map(&:id)}" # XXX

    result
  end
end
