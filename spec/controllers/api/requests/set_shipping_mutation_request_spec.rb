require 'rails_helper'
require 'support/gravity_helper'
require 'support/taxjar_helper'

describe Api::GraphqlController, type: :request do
  describe 'set_shipping mutation' do
    include_context 'GraphQL Client'
    let(:partner_id) { jwt_partner_ids.first }
    let(:user_id) { jwt_user_id }
    let(:order) { Fabricate(:order, partner_id: partner_id, user_id: user_id) }
    let!(:line_items) { [Fabricate(:line_item, order: order, artwork_id: 'a-1'), Fabricate(:line_item, order: order, artwork_id: 'a-2')] }
    let(:artwork1) { gravity_v1_artwork(domestic_shipping_fee_cents: 200_00, international_shipping_fee_cents: 300_00) }
    let(:artwork2) { gravity_v1_artwork(domestic_shipping_fee_cents: 400_00, international_shipping_fee_cents: 500_00) }
    let(:shipping_country) { 'IR' }
    let(:fulfillment_type) { 'SHIP' }
    let(:total_sales_tax) { 2222 }
    let(:partner) { { billing_location_id: '123abc' } }
    let(:partner_location) { { address: '123 Main St', address_2: nil, city: 'New York', state: 'NY', country: 'US', postal_code: 10_001 } }

    let(:mutation) do
      <<-GRAPHQL
        mutation($input: SetShippingInput!) {
          setShipping(input: $input) {
            order {
              id
              userId
              partnerId
              state
              shippingTotalCents
              requestedFulfillment {
                __typename
                ... on Ship {
                  addressLine1
                }
              }
            }
            errors
          }
        }
      GRAPHQL
    end

    let(:set_shipping_input) do
      {
        input: {
          id: order.id.to_s,
          fulfillmentType: fulfillment_type,
          shipping: {
            name: 'Fname Lname',
            country: shipping_country,
            city: 'Tehran',
            region: 'Tehran',
            postalCode: '02198912',
            addressLine1: 'Vanak',
            addressLine2: 'P 80'
          }
        }
      }
    end

    before do
      stub_tax_for_order
    end

    context 'with user without permission to this order' do
      let(:user_id) { 'random-user-id-on-another-order' }
      it 'returns permission error' do
        response = client.execute(mutation, set_shipping_input)
        expect(response.data.set_shipping.errors).to include 'Not permitted'
        expect(order.reload.state).to eq Order::PENDING
      end
    end

    context 'with proper permission' do
      context 'with order in non-pending state' do
        before do
          order.update! state: Order::APPROVED
        end
        it 'returns error' do
          response = client.execute(mutation, set_shipping_input)
          expect(response.data.set_shipping.errors).to include 'Cannot set shipping info on non-pending orders'
          expect(order.reload.state).to eq Order::APPROVED
        end
      end

      it 'sets shipping info and sales tax on the order' do
        allow(Adapters::GravityV1).to receive(:request).twice.with('/artwork/a-1').and_return(artwork1)
        allow(Adapters::GravityV1).to receive(:request).twice.with('/artwork/a-2').and_return(artwork2)
        allow(GravityService).to receive(:fetch_partner).and_return(partner)
        allow(GravityService).to receive(:fetch_partner_location).and_return(partner_location)
        response = client.execute(mutation, set_shipping_input)
        expect(response.data.set_shipping.order.id).to eq order.id.to_s
        expect(response.data.set_shipping.order.state).to eq 'PENDING'
        expect(response.data.set_shipping.errors).to match []
        expect(response.data.set_shipping.order.requested_fulfillment.address_line1).to eq 'Vanak'
        expect(order.reload.fulfillment_type).to eq Order::SHIP
        expect(order.state).to eq Order::PENDING
        expect(order.shipping_country).to eq 'IR'
        expect(order.shipping_city).to eq 'Tehran'
        expect(order.shipping_region).to eq 'Tehran'
        expect(order.shipping_postal_code).to eq '02198912'
        expect(order.shipping_name).to eq 'Fname Lname'
        expect(order.shipping_address_line1).to eq 'Vanak'
        expect(order.shipping_address_line2).to eq 'P 80'
        expect(order.state_expires_at).to eq(order.state_updated_at + 2.days)
        expect(order.tax_total_cents).to eq 232
      end

      describe '#shipping_total_cents' do
        before do
          expect(Adapters::GravityV1).to receive(:request).twice.with('/artwork/a-1').and_return(artwork1)
          expect(Adapters::GravityV1).to receive(:request).twice.with('/artwork/a-2').and_return(artwork2)
          allow(GravityService).to receive(:fetch_partner).and_return(partner)
          allow(GravityService).to receive(:fetch_partner_location).and_return(partner_location)
        end
        context 'with PICKUP as fulfillment type' do
          let(:fulfillment_type) { 'PICKUP' }
          it 'sets total shipping cents to 0' do
            response = client.execute(mutation, set_shipping_input)
            expect(response.data.set_shipping.order.shipping_total_cents).to eq 0
            expect(order.reload.shipping_total_cents).to eq 0
          end
        end
        context 'with SHIP as fulfillment type' do
          context 'with international shipping' do
            it 'sets total shipping cents properly' do
              response = client.execute(mutation, set_shipping_input)
              expect(response.data.set_shipping.order.shipping_total_cents).to eq 800_00
              expect(order.reload.shipping_total_cents).to eq 800_00
            end
          end

          context 'with domestic shipping' do
            let(:shipping_country) { 'US' }
            it 'sets total shipping cents properly' do
              response = client.execute(mutation, set_shipping_input)
              expect(response.data.set_shipping.order.shipping_total_cents).to eq 600_00
              expect(order.reload.shipping_total_cents).to eq 600_00
            end
          end

          context 'with one free shipping artwork' do
            let(:artwork1) { gravity_v1_artwork(domestic_shipping_fee_cents: 200_00, international_shipping_fee_cents: 0) }
            it 'sets total shipping cents only based on non-free shipping artwork' do
              response = client.execute(mutation, set_shipping_input)
              expect(response.data.set_shipping.order.shipping_total_cents).to eq 500_00
              expect(order.reload.shipping_total_cents).to eq 500_00
            end
          end
        end
      end
    end
  end
end
