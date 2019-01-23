require 'rails_helper'

describe Api::GraphqlController, type: :request do
  describe 'orders pagination query' do
    include_context 'GraphQL Client'

    let(:seller_id) { jwt_partner_ids.first }

    context 'with only the seller id parameter' do
      before do
        Fabricate.times(10, :order, seller_id: seller_id)
        Fabricate.times(1, :order, seller_id: 'foo')
        Fabricate.times(1, :order, seller_id: 'bar')
      end

      let(:query) do
        <<-GRAPHQL
          query($sellerId: String) {
            orders(sellerId: $sellerId) {
              edges {
                cursor
                node {
                  id
                }
              }
            }
          }
        GRAPHQL
      end

      it 'finds all orders placed with that seller' do
        result = client.execute(query, sellerId: seller_id)
        expect(result.data.orders.edges.count).to eq 10
      end

      it 'generates a cursor for each order' do
        result = client.execute(query, sellerId: seller_id)
        expect(result.data.orders.edges[rand(0..9)].cursor).to_not be_nil
        expect(result.data.orders.edges[rand(0..9)].cursor).to be_a(String)
      end
    end

    context 'with the seller id and first parameters' do
      before do
        Fabricate.times(10, :order, seller_id: seller_id)
      end

      let(:query) do
        <<-GRAPHQL
            query($sellerId: String) {
              orders(sellerId: $sellerId, first: 2) {
                edges {
                  cursor
                  node {
                    id
                  }
                }
              }
            }
        GRAPHQL
      end

      let(:next_query) do
        <<-GRAPHQL
            query($sellerId: String, $after: String) {
              orders(sellerId: $sellerId, first: 2, after: $after) {
                edges {
                  cursor
                  node {
                    id
                  }
                }
              }
            }
        GRAPHQL
      end

      let(:next_query) do
        <<-GRAPHQL
            query($sellerId: String, $before: String) {
              orders(sellerId: $sellerId, last: 2, before: $before) {
                edges {
                  cursor
                  node {
                    id
                  }
                }
              }
            }
        GRAPHQL
      end

      it 'finds the first two orders placed with that seller' do
        result = client.execute(query, sellerId: seller_id)
        expect(result.data.orders.edges.count).to eq 2
      end

      it 'returns a curosr that can be used to find the next two orders placed with that seller' do
        result = client.execute(query, sellerId: seller_id)
        after = result.data.orders.edges[-1].cursor
        expect(after).to_not be_nil
        expect(after).to be_a(String)

        result = client.execute(next_query, sellerId: seller_id, after: after)
        expect(result.data.orders.edges.count).to eq 2
        next_after = result.data.orders.edges[-1].cursor
        expect(next_after).to_not be_nil
        expect(next_after).to be_a(String)
        expect(next_after).not_to eql(after)
      end
    end
  end
end
