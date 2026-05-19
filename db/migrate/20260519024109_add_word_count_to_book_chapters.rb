class AddWordCountToBookChapters < ActiveRecord::Migration[7.1]
  def change
    add_column :book_chapters, :word_count, :integer, default: 0, null: false, comment: '章节字数'
  end
end
