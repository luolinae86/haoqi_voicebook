# frozen_string_literal: true

class AddChapterIdToEbookPages < ActiveRecord::Migration[8.0]
  def change
    add_reference :ebook_pages, :chapter, foreign_key: true, after: :book_id
  end
end
