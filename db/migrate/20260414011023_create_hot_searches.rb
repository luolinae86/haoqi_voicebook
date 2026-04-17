class CreateHotSearches < ActiveRecord::Migration[8.0]
  def change
    create_table :hot_searches, comment: "热门搜索表" do |t|
      t.string :keyword, null: false, comment: "关键词"
      t.integer :search_count, null: false, default: 0, comment: "搜索次数"
      t.integer :sort_order, null: false, default: 0, comment: "排序"

      t.timestamps
    end
    add_index :hot_searches, :keyword, unique: true
    add_index :hot_searches, :sort_order
  end
end
