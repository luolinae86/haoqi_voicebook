class CreateCollectionItems < ActiveRecord::Migration[8.0]
  def change
    create_table :collection_items, comment: "合集项表" do |t|
      t.integer :collection_id, null: false, comment: "合集ID"
      t.integer :book_id, null: false, comment: "图书ID"
      t.integer :sort_order, null: false, default: 0, comment: "排序"

      t.timestamps
    end
    add_index :collection_items, :collection_id
    add_index :collection_items, :book_id
    add_index :collection_items, [:collection_id, :book_id], unique: true
  end
end
