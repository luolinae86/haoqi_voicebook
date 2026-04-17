class CreateReadingLevels < ActiveRecord::Migration[8.0]
  def change
    create_table :reading_levels, comment: "分级阅读表" do |t|
      t.string :name, null: false, comment: "级别名称"
      t.integer :level, null: false, comment: "级别"
      t.text :description, comment: "描述"

      t.timestamps
    end
    add_index :reading_levels, :level, unique: true
  end
end
