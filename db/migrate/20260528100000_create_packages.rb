# frozen_string_literal: true

class CreatePackages < ActiveRecord::Migration[8.0]
  def change
    # packages 表已在生产环境存在，仅确保迁移记录被标记
    return if table_exists?(:packages)

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
