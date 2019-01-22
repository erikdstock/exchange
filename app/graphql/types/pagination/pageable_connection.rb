class Types::Pagination::PageableConnection < GraphQL::Types::Relay::BaseConnection
  field :page_cursors, Types::Pagination::PageCursorsType, null: false
  field :total_pages, Int, null: false
  field :total_count, Integer, null: false
  # we should be doing this earlier if we want to see hasPreviousPage
  GraphQL::Relay::ConnectionType.bidirectional_pagination = true
  def page_cursors
    {
      first: page_cursor(1),
      last: page_cursor(total_pages),
      around: around_page_numbers.map { |pn| page_cursor(pn) }
    }
  end

  def total_pages
    if object.nodes.size
      nodes_per_page ? (object.nodes.size.to_f / nodes_per_page).ceil : 1
    else
      0
    end
  end

  def total_count
    object.nodes.size
  end

  # A cursor for querying a given page number (after: cursor_for_page(8), first: nodes_per_page)
  # TODO: Why can't we just re-implement GraphQL::Relay::RelationConnection#cursor_from_node (below)?
  #  calling it via `object.cursor_from_node` for a node not in the edge_nodes throws an error,
  #  but from here we can generate it using the same method, which uses offset: http://graphql-ruby.org/pro/cursors#whats-the-difference'
  def cursor_for_page(page_num)
    if page_num > 1
      after_cursor = (page_num - 1) * nodes_per_page
      object.encode(after_cursor.to_s)
    else
      ## page 1 has no cursor
      ''
    end
  end
  ## From GraphQL::Relay::RelationConnection (our `object`)
  # def cursor_from_node(item)
  #   item_index = nodes.index(item)
  #   if item_index.nil?
  #     raise("Can't generate cursor, item not found in connection: #{item}")
  #   else
  #     offset = item_index + 1 + ((paged_nodes_offset || 0) - (relation_offset(sliced_nodes) || 0))

  #     if after
  #       offset += offset_from_cursor(after)
  #     elsif before
  #       offset += offset_from_cursor(before) - 1 - sliced_nodes_count
  #     end

  #     encode(offset.to_s)
  #   end
  # end

  # private

  def nodes_before
    node_offset(object.edge_nodes.first) - 1
  end

  def nodes_after
    node_offset(object.edge_nodes.last)
  end

  def node_offset(node)
    # this was previously accomplished by calling a private method: object.send(:offset_from_cursor, object.cursor_from_node(object.edge_nodes.first))
    object.nodes.index(node) + 1
  end


  def page_cursor(page_num)
    {
      cursor: cursor_for_page(page_num),
      is_current: current_page == page_num,
      page: page_num
    }
  end

  def current_page
    nodes_before / nodes_per_page + 1
  end

  # TODO:  clarify this behavior
  def around_page_numbers
    pages = if current_page == 1
              [1, 2, 3]
            elsif current_page == total_pages
              [total_pages - 2, total_pages - 1, total_pages]
            else
              [current_page - 1, current_page, current_page + 1]
            end
    pages.select { |p| p <= total_pages }.compact
  end

  def nodes_per_page
    object.first || object.last
  end
end
