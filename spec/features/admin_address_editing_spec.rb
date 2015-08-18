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
          @a = create(:address, user: user)
          @a.clone.save!
        end
      end

      scenario 'editing an address deduplicates it' do
        id = Spree::AddressBookList.new(user).find(@a).id

        expect {
          edit_address(user, id, true, Spree.t(:first_name) => 'NewFirstName')
        }.to change{ user.reload.addresses.count }.by(-1)

        expect(Spree::Address.find(id).firstname).to eq('NewFirstName')
      end

      scenario 'creating an address links it to the user' do
        expect {
          create_address(user, true, build(:address))
        }.to change{ user.reload.addresses.count }.by(1)
      end

      scenario 'trying to create an identical address deduplicates it' do
        expect {
          create_address(user, true, @a)
        }.to change{ user.reload.addresses.count }.by(-1)
      end
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
            firstname: 'First',
            lastname: 'Last',
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

        context 'creating an address' do
          scenario 'defaults to the empty slot' do
            a = build(:address, firstname: "Ship's")

            expect {
              create_address(guest_order, true, a)
            }.not_to change{ guest_order.reload.bill_address.comparison_attributes }

            expect(guest_order.ship_address.firstname).to eq("Ship's")
            expect(guest_order.ship_address.comparison_attributes).to eq(a.comparison_attributes)
            expect_address_count(2)


            b = build(:address, firstname: "Bill's")

            guest_order.update_columns(bill_address_id: nil)
            expect {
              create_address(guest_order, true, b)
            }.not_to change{ guest_order.reload.ship_address.comparison_attributes }

            # Note: using #comparison_attributes instead of #same_as? so RSpec will show a diff.
            expect(guest_order.ship_address.lastname).to eq("Bill's")
            expect(guest_order.bill_address.comparison_attributes).to eq(b.comparison_attributes)
            expect_address_count(2)
          end

          scenario 'can overwrite the existing slot without filling the other' do
            a = build(:address, firstname: 'OverwriteBill')

            expect {
              create_address(guest_order, true, a, :bill)
            }.not_to change{ guest_order.reload.bill_address_id }

            expect(guest_order.bill_address.comparison_attributes).to eq(a.comparison_attributes)
            expect(guest_order.ship_address).to be_nil


            b = build(:address, firstname: 'OverwriteShip')

            guest_order.update_columns(bill_address_id: nil, ship_address_id: guest_order.bill_address_id)
            expect {
              create_address(guest_order, true, b, :ship)
            }.not_to change{ guest_order.reload.ship_address_id }

            expect(guest_order.ship_address.comparison_attributes).to eq(b.comparison_attributes)
            expect(guest_order.bill_address).to be_nil
          end

          scenario 'overwrites correctly if the address is the same as the existing address' do
            a = build(:address, guest_order.bill_address.comparison_attributes)

            expect(guest_order.bill_address.firstname.downcase).not_to eq(guest_order.bill_address.firstname)

            expect {
              create_address(guest_order, true, a, :bill)
            }.not_to change{ guest_order.reload.bill_address_id }

            expect(guest_order.bill_address.firstname.downcase).to eq(guest_order.bill_address.firstname)
            expect(guest_order.ship_address).to be_nil
          end
        end
      end
    end

    context 'with a logged-in order' do
      context 'with no user addresses' do
        context 'with an incomplete order' do
          context 'with one address object' do
            before(:each) do
              order.update_columns(bill_address_id: order.ship_address_id)
              expect(order.bill_address_id).to eq(order.ship_address_id)
            end

            context 'with one slot blank' do
              scenario 'editing shipping does not assign it to billing' do
                order.update_columns(bill_address_id: nil)

                expect {
                  edit_address(order, order.ship_address_id, true, Spree.t(:first_name) => 'ShipFirst')
                  expect_address_count(1)
                }.not_to change{order.reload.ship_address_id}

                expect(order.bill_address_id).to be_nil
                expect(order.ship_address.firstname).to eq('ShipFirst')
              end

              scenario 'editing billing does not assign it to shipping' do
                order.update_columns(ship_address_id: nil)

                expect {
                  edit_address(order, order.bill_address_id, true, Spree.t(:first_name) => 'BillFirst')
                  expect_address_count(1)
                }.not_to change{order.reload.bill_address_id}

                expect(order.ship_address_id).to be_nil
                expect(order.bill_address.firstname).to eq('BillFirst')
              end

              scenario 'creating an address assigns it to the blank slot' do
                order.update_columns(bill_address_id: nil)

                # FIXME: non-guest orders don't have the dropdown

                a = build(:address, firstname: 'Ship')

                expect {
                  create_address(order, true, a)
                }.not_to change{ order.reload.bill_address.comparison_attributes }

                expect(order.ship_address.comparison_attributes).to eq(a.comparison_attributes)
                expect_address_count(2)


                b = build(:address, firstname: 'Bill')

                order.update_columns(bill_address_id: nil)
                expect {
                  create_address(order, true, b)
                }.not_to change{ order.reload.ship_address.comparison_attributes }

                expect(order.bill_address.comparison_attributes).to eq(b.comparison_attributes)
                expect_address_count(2)
              end
            end

            scenario 'editing the address links it to the user, leaving one object' do
              uaddrcount(user, "RSpec:edit1a:b4", order: order) # XXX

              visit_order_addresses(order)
              expect_address_count(1)

              uaddrcount(user, "RSpec:edit1a:mid", order: order) # XXX

              edit_address(order, order.ship_address_id, true, Spree.t(:first_name) => 'NewFirst')
              expect_address_count(1)

              uaddrcount(user, "RSpec:edit1a:aft", order: order) # XXX

              expect(order.reload.bill_address_id).to eq(order.ship_address_id)
              expect(order.bill_address_id).to be_present
              expect(order.ship_address_id).to be_present
              expect(user.reload.addresses.count).to eq(1)
              expect(order.bill_address.firstname).to eq('NewFirst')
            end
          end

          context 'with two identical addresses' do
            before(:each) do
              a = order.ship_address.clone
              a.save!
              order.update_columns(bill_address_id: a.id)
              expect(order.bill_address_id).not_to eq(order.ship_address_id)
            end

            scenario 'editing the address destroys one, shares and links the other to the user' do
              visit_order_addresses(order)
              expect_address_count(1)

              edit_address(order, order.bill_address_id, true, Spree.t(:first_name) => 'FirstNew')
              expect_address_count(1)

              expect(order.reload.bill_address_id).to eq(order.ship_address_id)
              expect(order.bill_address_id).to be_present
              expect(order.ship_address_id).to be_present
              expect(order.ship_address.firstname).to eq('FirstNew')
              expect(user.reload.addresses.count).to eq(1)
              expect(user.addresses.first.id).to eq(order.bill_address_id)
            end
          end

          context 'with two different addresses' do
            scenario 'editing one address does not affect the other, links both to the user' do
              uaddrcount(user, 'RSpec:eoadnatolbttu:b4', order: order) # XXX

              visit_order_addresses(order)
              expect_address_count(2)

              uaddrcount(user, 'RSpec:eoadnatolbttu:mid', order: order) # XXX

              edit_address(order, order.bill_address_id, true, Spree.t(:first_name) => 'BillFirst')
              edit_address(order, order.ship_address_id, true, Spree.t(:first_name) => 'ShipFirst')
              expect_address_count(2)

              uaddrcount(user, 'RSpec:eoadnatolbttu:aft', order: order) # XXX

              # byebug # XXX

              expect(order.reload.bill_address).not_to be_same_as(order.ship_address)
              expect(order.bill_address_id).to be_present
              expect(order.ship_address_id).to be_present
              expect(order.bill_address.firstname).to eq('BillFirst')
              expect(order.ship_address.firstname).to eq('ShipFirst')

              expect(user.reload.addresses.count).to eq(2)
              expect(user.address_ids.sort).to eq([order.bill_address_id, order.ship_address_id].sort)
            end
          end
        end

        context 'with a complete order' do
          let(:order) { completed_order }
          make_addresses_editable

          context 'with one address object' do
            before(:each) do
              $show_addr_creation = true # XXX
              order.update_columns(bill_address_id: order.ship_address_id)
              expect(order.bill_address_id).to eq(order.ship_address_id)
            end

            after(:each) do
              $show_addr_creation = false # XXX
            end

            scenario 'editing the address creates two identical addresses without linking to user' do
              uaddrcount(user, "RSpec:edit1a:b4", order: order) # XXX

              visit_order_addresses(order)
              expect_address_count(1)

              uaddrcount(user, "RSpec:edit1a:mid", order: order) # XXX

              edit_address(order, order.ship_address_id, true, Spree.t(:first_name) => 'NewFirst')
              expect_address_count(1)

              uaddrcount(user, "RSpec:edit1a:aft", order: order) # XXX

              expect(order.reload.bill_address_id).not_to eq(order.reload.ship_address_id)
              expect(order.bill_address_id).to be_present
              expect(order.ship_address_id).to be_present
              expect(order.bill_address).to be_same_as(order.ship_address)
              expect(user.reload.addresses.count).to eq(0)
              expect(order.bill_address.firstname).to eq('NewFirst')
            end
          end

          context 'with two identical addresses' do
            before(:each) do
              a = order.ship_address.clone
              a.save!
              order.update_columns(bill_address_id: a.id)
              expect(order.bill_address_id).not_to eq(order.ship_address_id)
            end

            scenario 'editing the address updates both addresses without linking to user' do
              visit_order_addresses(order)
              expect_address_count(1)

              edit_address(order, order.bill_address_id, true, Spree.t(:first_name) => 'FirstNew')
              expect_address_count(1)

              expect(order.reload.bill_address_id).not_to eq(order.ship_address_id)
              expect(order.bill_address_id).to be_present
              expect(order.ship_address_id).to be_present
              expect(order.bill_address).to be_same_as(order.ship_address)
              expect(order.ship_address.firstname).to eq('FirstNew')

              expect(user.reload.addresses.count).to eq(0)
            end
          end

          context 'with two different addresses' do
            scenario 'editing one address does not affect the other' do
              visit_order_addresses(order)
              expect_address_count(2)

              edit_address(order, order.bill_address_id, true, Spree.t(:first_name) => 'BillFirst')
              edit_address(order, order.ship_address_id, true, Spree.t(:first_name) => 'ShipFirst')
              expect_address_count(2)

              expect(order.reload.bill_address).not_to be_same_as(order.ship_address)
              expect(order.bill_address_id).to be_present
              expect(order.ship_address_id).to be_present
              expect(order.bill_address.firstname).to eq('BillFirst')
              expect(order.ship_address.firstname).to eq('ShipFirst')

              expect(user.reload.addresses.count).to eq(0)
            end
          end
        end
      end

      context 'with one or more user addresses' do
        context 'with a detached order address' do
          let(:address) {
            a = completed_order.bill_address.clone
            a.update_attributes!(user: user)
            a
          }

          make_addresses_editable

          before(:each) do
            address
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
            expect(address.reload.firstname).to eq('FirstNameEdit')
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
            expect(user.bill_address.firstname).to eq('EditFirstName')
            expect(user.ship_address.lastname).to eq('LastEditName')
          end
        end
      end

      context 'with duplicate addresses' do
        let(:a) { create(:address, user: user) }
        before(:each) do
          4.times do
            a.clone.save!
          end
        end

        scenario 'deletes duplicates when editing an address' do
          expect(user.addresses.reload.count).to eq(5)
          edit_address(user, Spree::AddressBookList.new(user).first.id, true, Spree.t(:first_name) => 'Changed')
          expect(user.addresses.reload.count).to eq(1)
        end

        scenario 'deduplicates and reassigns when a default address is edited to match another address' do
          old_address = user.addresses.first
          address = create(:address, user: user)
          user.update_columns(bill_address_id: address.id, ship_address_id: address.id)

          edit_address(user, user.bill_address_id, true, old_address)
          expect(user.reload.addresses.count).to eq(1)
          expect(user.bill_address_id).not_to eq(address.id)
          expect(user.bill_address_id).to eq(user.addresses.first.id)
          expect(user.ship_address_id).to eq(user.addresses.first.id)
        end

        scenario 'corrects other incomplete orders when addresses are deduplicated' do
          id = user.address_ids[2]
          order.update_columns(bill_address_id: id, ship_address_id: id)
          completed_order.update_columns(bill_address_id: a.id, ship_address_id: a.id)

          expect(user.addresses.count).to eq(5)

          primary = Spree::AddressBookList.new(user).find(a).id
          expect(primary).not_to eq(a.id)
          expect(primary).not_to eq(id)

          edit_address(user, primary, true, Spree.t(:first_name) => 'Different')
          expect(Spree::AddressBookList.new(user).count).to eq(1)

          # 2 because address id=1 is not editable since completed_order owns it
          expect(user.reload.addresses.count).to eq(2)

          expect(order.reload.bill_address_id).to eq(primary)
          expect(order.ship_address_id).to eq(primary)

          # Make sure completed orders are not modified, even if they have invalid addresses
          expect(completed_order.reload.bill_address_id).to eq(a.id)
          expect(completed_order.ship_address_id).to eq(a.id)
        end
      end
    end
  end
end
