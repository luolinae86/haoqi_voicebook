class CreateBlacklistedBooks < ActiveRecord::Migration[8.0]
  def change
    create_table :blacklisted_books, comment: "黑名单图书表" do |t|
      t.integer :parental_control_id, null: false, comment: "家长管控ID"
      t.integer :book_id, null: false, comment: "图书ID"

      t.timestamps
    end
    add_index :blacklisted_books, :parental_control_id
    add_index :blacklisted_books, :book_id
    add_index :blacklisted_books, [:parental_control_id, :book_id], unique: true
  end
end
