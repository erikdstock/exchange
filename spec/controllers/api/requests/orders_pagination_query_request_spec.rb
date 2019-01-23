require 'rails_helper'

describe Api::GraphqlController, type: :request do
  describe 'orders pagination query' do
    include_context 'GraphQL Client'

    let(:seller_id) { jwt_partner_ids.first }

    context 'with no orders belonging to a seller' do
      before do
        # Fabricate.times(10, :order, seller_id: seller_id)
        Fabricate.times(1, :order, seller_id: 'foo')
        Fabricate.times(1, :order, seller_id: 'bar')
      end

      let(:query) do
        <<-GRAPHQL
          query($sellerId: String, $first: Int) {
            orders(sellerId: $sellerId, first: $first) {
              edges {
                cursor
                node {
                  id
                }
              }
              pageCursors {
                first {
                  cursor
                  isCurrent
                  page
                },
                last {
                  cursor
                  isCurrent
                  page
                },
                around {
                  cursor
                  isCurrent
                  page
                }
              }
            }
          }
        GRAPHQL
      end

      it 'returns an empty result without page cursors' do
        result = client.execute(query, sellerId: seller_id, first: 12)
        expect(result.data.orders.edges.count).to eq 0
        expect(result.data.orders.page_cursors).to be_nil
      end
    end

    context 'with 1 order' do
      it 'returns one page'
      it 'has the same first, last, and around page'
    end

    context 'with 99 orders belonging to a seller' do
      before do
        99.times.each { |i| Fabricate(:order, seller_id: seller_id, created_at: i.days.ago) }
      end

      let(:query) do
        <<-GRAPHQL
            query($sellerId: String, $first: Int, $after: String, $last: Int, $before: String) {
              orders(sellerId: $sellerId, first: $first, after: $after, last: $last, before: $before) {
                edges {
                  cursor
                  node {
                    id
                  }
                }
                pageCursors {
                  first {
                    cursor
                    isCurrent
                    page
                  },
                  last {
                    cursor
                    isCurrent
                    page
                  },
                  around {
                    cursor
                    isCurrent
                    page
                  }
                }
              }
            }
        GRAPHQL
      end

      it 'returns a page of 12 orders' do
        result = client.execute(query, sellerId: seller_id, first: 12)
        expect(result.data.orders.edges.count).to eq 12
      end

      it 'returns a curosr that can be used to find the next two orders placed with that seller' do
        result = client.execute(query, sellerId: seller_id, first: 12)
        first_page_after = result.data.orders.edges[-1].cursor
        expect(first_page_after).to_not be_nil
        expect(first_page_after).to be_a(String)

        result = client.execute(query, sellerId: seller_id, first: 12, after: first_page_after)
        expect(result.data.orders.edges.count).to eq 12
        next_page_after = result.data.orders.edges[-1].cursor
        expect(next_page_after).to_not be_nil
        expect(next_page_after).to be_a(String)
        expect(next_page_after).not_to eql(first_page_after)

        next_page_before = result.data.orders.edges[0].cursor
        result = client.execute(query, sellerId: seller_id, last: 12, before: next_page_before)
        expect(result.data.orders.edges.count).to eq 12
        prev_page_after = result.data.orders.edges[-1].cursor
        expect(prev_page_after).to_not be_nil
        expect(prev_page_after).to be_a(String)
        expect(prev_page_after).to eq(first_page_after)
      end

      it 'jumps to the last page' do
        result = client.execute(query, sellerId: seller_id, first: 10)
        last_page_cursor = result.data.orders.page_cursors.last.cursor
        expect(last_page_cursor).to_not be_nil
        expect(last_page_cursor).to be_a(String)
        expect(result.data.orders.page_cursors.first.is_current).to be true

        result = client.execute(query, sellerId: seller_id, first: 10, after: last_page_cursor)
        expect(result.data.orders.edges.size).to eq 9
        expect(result.data.orders.page_cursors.last.is_current).to be true
        expect(result.data.orders.page_cursors.first.is_current).to be false
      end
    end
  end
end
