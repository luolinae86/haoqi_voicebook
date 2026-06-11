# frozen_string_literal: true

class CreatePushNotifications < ActiveRecord::Migration[8.0]
  def change
    return if table_exists?(:push_notifications)

    create_table :push_notifications do |t|
      t.string :title, null: false
      t.string :body, null: false
      t.integer :push_type, null: false, default: 0
      t.integer :push_scope, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.boolean :is_delete, default: false
      t.string :link_url
      t.integer :min_age
      t.integer :max_age
      t.text :user_group
      t.integer :send_count, default: 0
      t.integer :click_count, default: 0
      t.decimal :delivery_rate, default: 0.0
      t.datetime :scheduled_at
      t.datetime :sent_at
      t.timestamps
    end

    add_index :push_notifications, :push_type unless index_exists?(:push_notifications, :push_type)
    add_index :push_notifications, :status unless index_exists?(:push_notifications, :status)
  end
end
