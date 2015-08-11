require 'spec_helper'

feature 'Admin UI address editing' do
  stub_authorization!

  let(:user) { create(:user) }
  let(:order) { strip_order_address_users(create(:order_with_line_items, user: user)) }
  let(:completed_order) { create(:completed_order_with_pending_payment, user: user) }
  let(:shipped_order) { create(:shipped_order, user: user) }
  let(:guest_order) { strip_order_address_users(create(:order_with_line_items, user: nil, email: 'guest@example.com')) }

  describe 'User account address list' do
    scenario 'can edit a single address' do
      a = create(:address, user: user)

      expect {
        edit_address(
          user,
          a.id,
          true,
          Spree.t(:street_address_2) => 'new_address_two'
        )
      }.not_to change{user.reload.addresses.count}

      expect(a.reload.address2).to eq('new_address_two')
      expect(user.addresses.last.id).to eq(a.id)
      expect(a.deleted_at).to be_nil
    end

    context 'with duplicate addresses' do
      before(:each) do
        user.update_attributes!(
          ship_address: create(:address, user: user),
          bill_address: create(:address, user: user)
        )

        # Set up duplicate addresses
        3.times do
          a = create(:address, user: user)
          a.clone.save!
        end
      end

      pending
    end
  end


  describe 'Order address list' do
    context 'with a guest order' do
      context 'with only one address' do
        before(:each) do
          guest_order.update_attributes!(ship_address: nil)
        end

        scenario 'cannot edit a different address not from the order' do
          a = create(:address)
          visit(spree.edit_admin_address_path(a.id, order_id: guest_order.id))
          expect(path_with_query).to eq(spree.admin_addresses_path(order_id: guest_order.id))
          expect(page).to have_content(Spree.t(:not_found, resource: Spree::Address.model_name.human))
        end

        scenario 'can edit the order address' do
          a = build(
            :address,
            first_name: 'First',
            last_name: 'Last',
            company: 'Company',
            address1: '123 Fake',
            address2: 'Floor Three',
            city: 'Beverly Hills',
            phone: '555-555-5555',
            alternative_phone: '555-555-5556'
          )

          expect(a).to be_valid

          orig_id = guest_order.bill_address_id

          expect {
            edit_address(
              guest_order,
              guest_order.bill_address,
              true,
              a
            )
          }.not_to change{ Spree::Address.count }

          expect(guest_order.reload.bill_address_id).to eq(orig_id)
          expect(guest_order.bill_address).to be_same_as(a)
          expect(guest_order.ship_address).to be_nil
        end
      end

      pending
    end

    context 'with a logged-in order' do
      context 'with no user addresses' do
        context 'with one address object' do
          before(:each) do
            order.update_attributes!(bill_address_id: order.ship_address_id)
            expect(order.bill_address_id).to eq(order.ship_address_id)
          end

          scenario 'editing the address creates two identical addresses' do
            visit_order_addresses(order)
            expect_address_count(1)

            edit_address(order, order.ship_address_id, true, Spree.t(:first_name) => 'NewFirst')
            expect_address_count(1)

            expect(order.reload.bill_address_id).not_to eq(order.ship_address_id)
            expect(order.bill_address).to be_same_as(order.ship_address)
            expect(order.bill_address.first_name).to eq('NewFirst')
          end
        end

        context 'with two identical addresses' do
          before(:each) do
            order.update_attributes!(bill_address: order.ship_address.clone)
            expect(order.bill_address_id).not_to eq(order.ship_address_id)
          end

          scenario 'editing the address updates both addresses' do
            visit_order_addresses(order)
            expect_address_count(1)

            edit_address(order, order.bill_address_id, true, Spree.t(:first_name) => 'FirstNew')
            expect_address_count(1)

            expect(order.bill_address_id).not_to eq(order.ship_address_id)
            expect(order.bill_address).to be_same_as(order.ship_address)
            expect(order.ship_address.first_name).to eq('FirstNew')
          end
        end

        context 'with two different addresses' do
          pending
        end
      end

      context 'with one or more user addresses' do
        context 'with a detached order address' do
          let(:address) {
            a = completed_order.bill_address.clone
            a.update_attributes!(user: user)
            a
          }

          before(:each) do
            # Allow editing of completed order addresses
            Spree::Address.class_eval do
              alias_method :orig_editable?, :editable?
              def editable?
                true
              end
            end

            address
          end

          after(:each) do
            # Restore original #editable? method
            Spree::Address.class_eval do
              alias_method :editable?, :orig_editable?
            end
          end

          scenario 'edits both user and order address objects directly' do
            expect(user.reload.addresses.count).to eq(1)

            bill = completed_order.bill_address

            expect {
              expect {
                edit_address(completed_order, address, true, Spree.t(:first_name) => 'FirstNameEdit')
              }.to change{ [address.reload.updated_at, bill.reload.updated_at] }
            }.not_to change{
              [completed_order.reload.bill_address_id, completed_order.reload.ship_address_id, user.reload.address_ids.sort]
            }

            expect(address.id).not_to eq(completed_order.bill_address_id)
            expect(address.reload.first_name).to eq('FirstNameEdit')
            expect(address.comparison_attributes.except('user_id')).to eq(completed_order.bill_address.reload.comparison_attributes.except('user_id'))
          end
        end

        context 'with a shared order address' do
          scenario 'preserves shared address assignments when editing' do
            order.bill_address.update_attributes!(user: user)
            order.ship_address.update_attributes!(user: user)
            user.update_attributes!(
              bill_address: order.bill_address,
              ship_address: order.ship_address
            )

            expect {
              edit_address(order, order.bill_address, true, Spree.t(:first_name) => 'EditFirstName')
              edit_address(order, order.ship_address, true, Spree.t(:last_name) => 'LastEditName')
            }.not_to change{
              [order.reload.bill_address_id, order.ship_address_id, user.reload.address_ids.sort]
            }

            expect(user.bill_address_id).to eq(order.bill_address_id)
            expect(user.bill_address.first_name).to eq('EditFirstName')
            expect(user.ship_address.last_name).to eq('LastEditName')
          end
        end

        pending
      end

      context 'with duplicate addresses' do
        before(:each) do
          a = create(:address, user: user)
          4.times do
            a.clone.save!
          end
        end

        it 'deletes duplicates when editing an address' do
          expect(user.addresses.reload.count).to eq(5)
          edit_address(user, Spree::AddressBookList.new(user).first.id, true, Spree.t(:first_name) => 'Changed')
          expect(user.addresses.reload.count).to eq(1)
        end

        pending 'deduplicates when an address is edited to match another address'

        pending
      end
    end
  end
end
