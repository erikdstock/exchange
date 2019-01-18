class Types::OrderEdgeType < GraphQL::Types::Relay::BaseEdge
  node_type(Types::OrderInterface)
end

class PageCursorType < Types::BaseObject
  field :cursor, String, 'first cursor on the page', null: false
  field :isCurrent, Boolean, 'is this the current page?', null: false
  field :page, Int, 'page number out of totalPages', null: false
end

class PageCursorsType < Types::BaseObject
  field :first, PageCursorType, 'optional, may be included in field around', null: true
  field :last, PageCursorType, 'optional, may be included in field around', null: true
  field :around, [PageCursorType], null: true
end

class FakePageCursors
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

  field :page_cursors, PageCursorsType, 'Page cursors', null: false

  def page_cursors
    # byebug # UNCOMMENT ME

    {
      first:
      {
        cursor: "abc", #object.cursor_from_node(object.nodes.first),
        is_current: false,
        page: 1
      },

      last:
      {
        cursor: 'woot',
        is_current: false,
        page: total_pages
      },
      around:
      [{
        cursor: 'woot',
        is_current: false,
        page: 3
      }, {
        cursor: 'woot',
        is_current: true,
        page: 4
      }, {
        cursor: 'woot',
        is_current: false,
        page: 5
      }]
    }
  end

  # def all_page_cursors(all_nodes, page_size)
  #   all_nodes.each_slice(page_size).map do |page|
  #     {
  #       cursor: get_cursor_for_node(page.first)
  #       is_current: page.include?(this_pages_cursor)
  #       page: index
  #     }
  #   end
  # end
  # all_nodes.each_slice(12)

  def last_page_first_node
    # object.nodes[-first]
  end

  def total_pages
    5
    # object.nodes.any? object.nodes.count / first + 1 | 0
  end
end
