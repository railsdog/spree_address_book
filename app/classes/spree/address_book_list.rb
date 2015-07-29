# Represents a list of addresses from an order and/or user.  Performs address
# deduplication by Spree::Address#same_as?, using Spree::AddressBookGroup to
# represent groups of identical addresses.  Could probably be optimized.
class Spree::AddressBookList
  # Address sources for this list.
  attr_reader :user, :order

  # User and order assigned addresses.
  attr_reader :user_ship, :user_bill, :order_ship, :order_bill

  # A list of deduplicated Spree::Address or Spree::AddressBookGroup objects.
  attr_reader :addresses

  delegate :count, :size, :length, :[], :first, :last, :each, :map, :select, :reject, to: :addresses


  # Initializes an address list with the addresses from the given user and/or
  # order, which may be passed in any order.
  def initialize(user_or_order, order_or_user=nil)
    if user_or_order.is_a?(Spree::User)
      @user = user_or_order
      @order = order_or_user
    else
      @user = order_or_user
      @order = user_or_order
    end

    raise 'No user or order was given' if user_or_order.nil? && order_or_user.nil?
    raise 'User must be nil or a Spree::User' unless user.nil? || user.is_a?(Spree::User)
    raise 'Order must be nil or a Spree::Order' unless order.nil? || order.is_a?(Spree::Order)

    addresses = []

    if @user
      @user_ship = check_user_address(user, :ship_address)
      @user_bill = check_user_address(user, :bill_address)

      addresses << @user_ship if @user_ship
      addresses << @user_bill if @user_bill
      addresses.concat(@user.addresses)
    end

    if @order
      @order_ship = check_order_address(user, order, :ship_address)
      @order_bill = check_order_address(user, order, :bill_address)
      addresses << @order_ship if @order_ship
      addresses << @order_bill if @order_bill
    end

    addresses.uniq!(&:id)

    @addresses = addresses.uniq(&:id).group_by{|a| a.comparison_attributes.except('user_id') }.map{|k, v|
      if v.count > 1
        assignments = {}
        assignments[:user_ship] = @user_ship if v.include?(@user_ship)
        assignments[:user_bill] = @user_bill if v.include?(@user_bill)
        assignments[:order_ship] = @order_ship if v.include?(@order_ship)
        assignments[:order_bill] = @order_bill if v.include?(@order_bill)

        Spree::AddressBookGroup.new(v, assignments)
      else
        v.first
      end
    }.compact.sort_by(&:updated_at).reverse
  end

  private
  # Makes sure the +user+ owns their default address of the given +type+
  # (:ship_address or :bill_address).
  def check_user_address(user, type)
    addr = user.send(type)

    if addr && addr.user_id != user.id
      Rails.logger.warn "BUG!!!  User #{user.id} does not own their #{type} #{addr.id}.  Cloning it."
      begin
        addr = addr.clone.save!
        addr.update_attributes!(user: user)
        user.update_attributes(type => addr)
      rescue => e
        # Handle any invalid addresses that got saved somehow
        Rails.logger.error "Error fixing user #{user.id} #{type}.  Clearing it."
        user.send("#{type}=", nil)
        addr = nil
      end
    end

    addr
  end

  # Makes sure the +order+ address of the given +type+ belongs to the given
  # +user+ if specified, the order's user if unspecified, or nobody.
  def check_order_address(user, order, type)
    addr = order.send(type)
    user ||= order.user

    if addr && addr.user_id && addr.user_id != user.try(:id)
      raise "Order #{order.id} has address that belongs to user #{addr.user_id.inspect} instead of #{user.try(:id).inspect}"
    end

    addr
  end
end
