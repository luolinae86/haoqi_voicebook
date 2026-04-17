class CreateGrades < ActiveRecord::Migration[8.0]
  def change
    create_table :grades, comment: "年级表" do |t|
      t.string :name, null: false, comment: "年级名称"
      t.integer :level, null: false, comment: "年级等级"
      t.integer :sort_order, null: false, default: 0, comment: "排序"
      t.string :description, comment: "描述"

      t.timestamps
    end
    add_index :grades, :level, unique: true
    add_index :grades, :sort_order
  end
end
