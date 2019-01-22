class Types::Pagination::PageableConnection < GraphQL::Types::Relay::BaseConnection
  field :page_cursors, Types::Pagination::PageCursorsType, null: false
  field :total_pages, Int, null: false
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

  def nodes_before
    object.send(:offset_from_cursor, object.cursor_from_node(object.edge_nodes.first)) - 1
  end

  def nodes_after
    object.nodes.size - object.send(:offset_from_cursor, object.cursor_from_node(object.edge_nodes.last))
  end

  # A cursor for querying a given page number (after: cursor_for_page(8), first: nodes_per_page)
  def cursor_for_page(page_num)
    if page_num > 1 ## page 1 has no cursor
      after_cursor = (page_num - 1) * nodes_per_page
      object.encode(after_cursor.to_s)
    else
      nil
    end
  end
  
  def page_cursor(page_num)
    byebug if page_num == 1
    {
      cursor: cursor_for_page(page_num),
      is_current: current_page == page_num,
      page: page_num
    }
  end

  def current_page
    nodes_before / nodes_per_page + 1
  end

  def around_page_numbers
    if current_page == 1
      pages = [1, 2, 3]
    elsif current_page == total_pages
      pages = [total_pages - 2, total_pages - 1, total_pages]
    else
      pages = [current_page - 1, current_page, current_page + 1]
    end
    pages.select { |p| p <= total_pages }.compact
  end

  def page_cursors
    byebug # UNCOMMENT ME

    {
      first: page_cursor(1),
      last: page_cursor(total_pages),
      around: around_page_numbers.map { |pn| page_cursor(pn) }
      # first: {
      #   cursor: nil, # object.cursor_from_node(object.nodes.first),
      #   is_current: false,
      #   page: 1
      # },

      # last: {
      #   cursor: cursor_for_page(total_pages),
      #   is_current: false,
      #   page: total_pages
      # },
      # around:
      # [{
      #   cursor: 'woot',
      #   is_current: false,
      #   page: 3
      # }, {
      #   cursor: 'woot',
      #   is_current: true,
      #   page: 4
      # }, {
      #   cursor: 'woot',
      #   is_current: false,
      #   page: 5
      # }]
    }
  end

  def total_pages
    if object.nodes.size
      nodes_per_page ? (object.nodes.size.to_f / nodes_per_page).ceil : 1
    else
      0
    end
  end

  def nodes_per_page
    object.first || object.last
  end
end
