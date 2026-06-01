# frozen_string_literal: true

class CreateUserSearches < ActiveRecord::Migration[8.0]
  def change
    create_table :user_searches do |t|
      t.references :app_user, null: false, foreign_key: true
      t.string :keyword, null: false, comment: '搜索关键词'
      t.timestamps
    end
    add_index :user_searches, [:app_user_id, :created_at]
  end
end
