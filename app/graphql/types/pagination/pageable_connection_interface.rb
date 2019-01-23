
module Types::Pagination::PageableConnectionInterface
  include Types::BaseInterface
  ######## WIP ######
  # Missing implementations/data: items per page, total pages, efficient method for getting the "around" pages
  PageCursor = Struct.new(:cursor, :isCurrent?, :page) # temporary, not even sure if this will work, probably should have some kind of service class that does this for us?

  ## Known things
  # self.object should be a BaseConnection: https://www.rubydoc.info/gems/graphql/GraphQL/Relay/BaseConnection
  # object.nodes is all nodes, object.edge_nodes is the nodes in edges on this page
  # being that this is pagination we should have first, last, (Ints) before and after (cursors) available

  # I think current page number could be resolved client-side using these, eg current_page = count_before/count_per_page + 1
  field :count_before, Int, 'number of cursors before the first cursor in this connection', null: false
  field :count_after, Int, 'number of objects after the last cursor in this page', null: false


  # Since we are using PageCursors, the # per page is always the `first` argument passed into the query.
  def items_per_page
    object.first
  end

  def nodes_before(node)
    object.nodes.take_while { |n| n.cursor != node.cursor }
  end

  def nodes_after(node)
    object.nodes.drop_while { |n| n.cursor != node.cursor }.drop(1)
  end

  def count_after
    nodes_after(last_node_in_page).count
  end

  def count_before
    nodes_before(first_node_in_page).count
  end

  field :page_cursors, Types::Pagination::PageCursorsType, 'Page cursors'

  def page_cursors
    {
      first: page_cursor_from_node(object.edge_nodes.first),
      last: page_cursor_from_node(object.edge_nodes[-items]),
      around: [] # "?????"
    }
  end

  def page_cursor_from_node(node)
    PageCursor.new(
      # cursor
      node.cursor,
      # isCurrent?
      edge_nodes.contains?(node),
      # page number
      count_before(node) / ITEMS_PER_PAGE + 1
    )
  end

  def first_node_in_page
    object.edge_nodes.first
  end

  def last_node_in_page
    object.edge_nodes.last
  end

  # def node_for_cursor?(cursor)
  #   object.nodes.find { |n| n.cursor == cursor }
  # end

end