# frozen_string_literal: true

class CreatePackages < ActiveRecord::Migration[8.0]
  def change
    create_table :packages do |t|
      t.string :name, limit: 255
      t.float :price
      t.float :origin_price
      t.integer :effective_days
      t.integer :sn, default: 0
      t.boolean :is_delete, default: false
      t.boolean :is_discount, default: false

      t.timestamps
    end

    add_index :packages, :is_delete
  end
end
