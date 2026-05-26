# frozen_string_literal: true

class CreateHotSearches < ActiveRecord::Migration[8.0]
  def change
    create_table :hot_searches do |t|
      t.string :keyword, null: false, comment: "关键词"
      t.integer :search_count, default: 0, null: false, comment: "搜索次数"
      t.integer :sort_order, default: 0, null: false, comment: "排序"
      t.index :keyword, unique: true

      t.timestamps
    end
  end
end
