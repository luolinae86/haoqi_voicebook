class CreateRecommendationItems < ActiveRecord::Migration[8.0]
  def change
    create_table :recommendation_items, comment: "推荐项表" do |t|
      t.integer :recommendation_id, null: false, comment: "推荐ID"
      t.integer :book_id, null: false, comment: "图书ID"
      t.integer :sort_order, null: false, default: 0, comment: "排序"

      t.timestamps
    end
    add_index :recommendation_items, :recommendation_id
    add_index :recommendation_items, :book_id
    add_index :recommendation_items, [:recommendation_id, :book_id], unique: true
  end
end
