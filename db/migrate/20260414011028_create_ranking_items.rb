class CreateRankingItems < ActiveRecord::Migration[8.0]
  def change
    create_table :ranking_items, comment: "排行项表" do |t|
      t.integer :ranking_id, null: false, comment: "排行榜ID"
      t.integer :book_id, null: false, comment: "图书ID"
      t.integer :rank, null: false, comment: "排名"
      t.decimal :score, precision: 5, scale: 2, default: 0.0, comment: "得分"

      t.timestamps
    end
    add_index :ranking_items, :ranking_id
    add_index :ranking_items, :book_id
    add_index :ranking_items, [:ranking_id, :book_id], unique: true
    add_index :ranking_items, [:ranking_id, :rank]
  end
end
