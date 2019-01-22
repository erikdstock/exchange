class Types::OrderEdgeType < GraphQL::Types::Relay::BaseEdge
  node_type(Types::OrderInterface)
end

# class PageCursorType < Types::BaseObject
#   field :cursor, String, 'first cursor on the page', null: false
#   field :isCurrent, Boolean, 'is this the current page?', null: false
#   field :page, Int, 'page number out of totalPages', null: false
# end

# class PageCursorsType < Types::BaseObject
#   field :first, PageCursorType, 'optional, may be included in field around', null: true
#   field :last, PageCursorType, 'optional, may be included in field around', null: true
#   field :around, [PageCursorType], null: true
# end

# class FakePageCursors
# end


class Types::OrderConnectionWithTotalCountType < Types::Pagination::PageableConnection
  # implements Types::Pagination::PageableConnectionInterface

  edge_type(Types::OrderEdgeType)

  field :total_count, Integer, null: false
  def total_count
    # - `object` is the Connection
    # - `object.nodes` is the collection of Orders
    object.nodes.size
  end

  def last_page_first_node
    # object.nodes[-first]
  end
end
