# frozen_string_literal: true

class AddIsActiveToHotSearches < ActiveRecord::Migration[8.0]
  def change
    add_column :hot_searches, :is_active, :boolean, default: true, null: false, comment: "是否启用"
    remove_index :hot_searches, :sort_order
    add_index :hot_searches, [:is_active, :sort_order]
  end
end
