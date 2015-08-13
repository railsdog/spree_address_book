class Spree::AddressesController < Spree::StoreController
  helper Spree::AddressesHelper
  include Spree::AddressUpdateHelper

  rescue_from ActiveRecord::RecordNotFound, :with => :render_404
  load_and_authorize_resource :class => Spree::Address

  before_filter :load_addresses, only: [:index, :create, :update]

  def create
    @address = spree_current_user.addresses.build(address_params)
    @address.user = spree_current_user

    # Only save the address if it doesn't match an existing address
    if @address.valid? && (@addresses.find(@address) || @address.save)
      flash[:notice] = Spree.t(:successfully_created, :resource => Spree.t(:address1))
      redirect_to account_path
    else
      flash[:error] = @address.errors.full_messages.to_sentence
      render :action => "new"
    end
  end

  def show
    redirect_to account_path
  end

  def edit
    session["spree_user_return_to"] = request.env['HTTP_REFERER']
  end

  def new
    @address = Spree::Address.default
  end

  def update
    if !@address.editable?
      a = @address.clone
      @address.update_attributes(user_id: nil)
      @address = a
    end

    # See app/helpers/spree/addresses_helper.rb
    @address, *_ = update_and_merge @address, @addresses

    if @address.errors.any?
      flash[:error] = @address.errors.full_messages.to_sentence
      render action: 'edit'
    else
      flash[:notice] = Spree.t(:successfully_updated, :resource => Spree.t(:address1))
      redirect_back_or_default(account_path)
    end
  end

  def destroy
    a = @addresses.try(:find, @address) || @address

    if a.destroy
      flash[:notice] = Spree.t(:successfully_removed, :resource => Spree.t(:address1))
    else
      flash[:error] = a.errors.full_messages.to_sentence
    end

    redirect_to(request.env['HTTP_REFERER'] || account_path) unless request.xhr?
  end

  private

  # Loads a deduplicated address list (Spree::AddressBookList) into @addresses.
  def load_addresses
    @addresses = Spree::AddressBookList.new(spree_current_user)
  end
end
