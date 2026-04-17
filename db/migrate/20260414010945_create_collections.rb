class CreateCollections < ActiveRecord::Migration[8.0]
  def change
    create_table :collections, comment: "专题合集表" do |t|
      t.string :title, null: false, comment: "合集标题"
      t.text :description, comment: "合集描述"
      t.string :cover_image, comment: "封面图片URL"
      t.integer :sort_order, null: false, default: 0, comment: "排序"
      t.integer :collection_type, null: false, default: 0, comment: "类型：0-专题 1-分级 2-热门 3-新上架"
      t.integer :target_grade_id, comment: "目标年级ID"

      t.timestamps
    end
    add_index :collections, :collection_type
    add_index :collections, :target_grade_id
    add_index :collections, :sort_order
  end
end
