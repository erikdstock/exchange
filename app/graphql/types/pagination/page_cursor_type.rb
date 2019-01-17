class Types::Pagination::PageCursorType < Types::BaseObject
  field :cursor, String,"first cursor on the page"        null: false
  field :isCurrent, Boolean, "is this the current page?", null: false
  field :page, Int, "page number out of totalPages" null: false
end

