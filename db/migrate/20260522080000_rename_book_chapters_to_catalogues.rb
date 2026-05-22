class RenameBookChaptersToCatalogues < ActiveRecord::Migration[8.0]
  def up
    return unless table_exists?(:book_chapters)

    rename_table :book_chapters, :catalogues
    if index_exists?(:catalogues, :book_id, name: 'index_book_chapters_on_book_id')
      rename_index :catalogues, 'index_book_chapters_on_book_id', 'index_catalogues_on_book_id'
    end
  end

  def down
    return unless table_exists?(:catalogues)

    if index_exists?(:catalogues, :book_id, name: 'index_catalogues_on_book_id')
      rename_index :catalogues, 'index_catalogues_on_book_id', 'index_book_chapters_on_book_id'
    end
    rename_table :catalogues, :book_chapters
  end
end
