module Authentication
  # Signs in as the given +user+ using #sign_in!, then clicks the My Account
  # link.  Expects all of the user's addresses to be listed.
  def visit_account(user)
    sign_in! user
    click_link Spree.t(:my_account)
    expect_list_addresses(user.addresses)
  end

  # Visits the Spree root path, clicks the Login link, and signs in as the
  # given +user+.
  def sign_in!(user)
    visit spree.root_path
    click_link Spree.t(:login)
    fill_in Spree.t(:email), :with => user.email
    fill_in Spree.t(:password), :with => "secret"
    click_button Spree.t(:login)
  end

  def sign_in_to_cart!(user)
    visit spree.login_path
    fill_in "Email", :with => user.email
    fill_in "Password", :with => "secret"
    click_button "Login"
    restart_checkout
  end

  def restart_checkout
    visit spree.cart_path
    click_button 'Checkout'
  end
end

RSpec.configure do |c|
  c.include Authentication, :type => :feature
end
