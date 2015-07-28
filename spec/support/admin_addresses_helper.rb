module AdminAddresses
  def visit_user_addresses(user)
    visit spree.admin_addresses_path(user_id: user.id)
    expect(page).to have_content(I18n.t(:new_address, scope: :address_book))
  end

  def expect_address_count(count)
    if count == 0
      expect{page.find('#addresses tbody tr')}.to raise_error(/CSS/i)
    else
      expect(page.all('#addresses tbody tr').count).to eq(count)
    end
  end
end

RSpec.configure do |c|
  c.include AdminAddresses, type: :feature
end
