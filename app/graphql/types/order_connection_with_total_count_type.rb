class Types::OrderEdgeType < GraphQL::Types::Relay::BaseEdge
  node_type(Types::OrderInterface)
end

class PageCursorType < Types::BaseObject
  field :cursor, String, 'first cursor on the page', null: false
  field :isCurrent, Boolean, 'is this the current page?', null: false
  field :page, Int, 'page number out of totalPages', null: false
end

class PageCursorsType < Types::BaseObject
  field first: PageCursorType, 'optional, may be included in field `around`', null: true
  field last: PageCursorType, 'optional, may be included in field `around`', null: true
  field around: [PageCursorType], null: true

  def first
    {
      cursor: 'woot',
      isCurrent: false,
      page: 1
    }
  end

  def last
    {
      cursor: 'woot',
      isCurrent: false,
      page: 10
    }
  end

  def around
    [{
      cursor: 'woot',
      isCurrent: false,
      page: 3
    }, {
      cursor: 'woot',
      isCurrent: true,
      page: 4
    }, {
      cursor: 'woot',
      isCurrent: false,
      page: 5
    }]
  end
end

class Types::OrderConnectionWithTotalCountType < GraphQL::Types::Relay::BaseConnection
  # implements Types::Pagination::PageableConnectionInterface

  edge_type(Types::OrderEdgeType)

  field :total_count, Integer, null: false
  def total_count
    # - `object` is the Connection
    # - `object.nodes` is the collection of Orders
    object.nodes.size
  end

  field :page_cursors, PageCursorsType, 'Page cursors'

end
