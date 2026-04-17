class CreateRecommendations < ActiveRecord::Migration[8.0]
  def change
    create_table :recommendations, comment: "推荐表" do |t|
      t.string :title, null: false, comment: "推荐标题"
      t.text :description, comment: "推荐描述"
      t.integer :recommendation_type, null: false, default: 0, comment: "类型：0-精选 1-分级 2-热门 3-新书 4-专题"
      t.integer :target_grade_id, comment: "目标年级ID"
      t.integer :sort_order, null: false, default: 0, comment: "排序"

      t.timestamps
    end
    add_index :recommendations, :recommendation_type
    add_index :recommendations, :target_grade_id
    add_index :recommendations, :sort_order
  end
end
