class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories, comment: "分类表" do |t|
      t.string :name, null: false, comment: "分类名称"
      t.integer :parent_id, comment: "父分类ID"
      t.integer :sort_order, null: false, default: 0, comment: "排序"
      t.string :icon, comment: "图标URL"
      t.string :description, comment: "描述"

      t.timestamps
    end
    add_index :categories, :parent_id
    add_index :categories, :sort_order
  end
end
