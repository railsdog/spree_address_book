class Spree::AddressesController < Spree::StoreController
  helper Spree::AddressesHelper
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
    new_address = @address.clone
    new_address.attributes = address_params
    match = @addresses.find(new_address)
    old_match = @addresses.find(@address)

    # TODO: This could probably be condensed (DRY) and made more readable
    if @address.editable?
      # Delete if address matches another address set, otherwise update
      if (match && match != old_match && @address.delete) || @address.update_attributes(address_params)
        flash[:notice] = Spree.t(:successfully_updated, :resource => Spree.t(:address1))
        redirect_back_or_default(account_path)
      else
        render :action => "edit"
      end
    else
      @address.update_attribute(:deleted_at, Time.now)

      # Save new address only if it doesn't match an existing address
      if (match && match != old_match) || new_address.save
        flash[:notice] = Spree.t(:successfully_updated, :resource => Spree.t(:address1))
        redirect_back_or_default(account_path)
      else
        flash[:error] = @address.errors.full_messages.to_sentence
        render :action => "edit"
      end
    end
  end

  def destroy
    @address.destroy

    flash[:notice] = Spree.t(:successfully_removed, :resource => Spree.t(:address1))
    redirect_to(request.env['HTTP_REFERER'] || account_path) unless request.xhr?
  end

  private

  def address_params
    params.require(:address).permit(:firstname, :lastname, :company, :address1, :address2, :city, :state_id, :state_name, :zipcode, :country_id, :phone, :alternative_phone)
  end

  # Loads a deduplicated address list (Spree::AddressBookList) into @addresses.
  def load_addresses
    @addresses = Spree::AddressBookList.new(spree_current_user)
  end
end
