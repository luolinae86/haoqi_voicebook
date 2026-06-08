class AddLevelAndSortOrderToGrades < ActiveRecord::Migration[8.0]
  def change
    add_column :grades, :level, :integer, null: false, default: 0
    add_column :grades, :sort_order, :integer, null: false, default: 0
    add_index :grades, :level, unique: true
    add_index :grades, :sort_order
  end
end
