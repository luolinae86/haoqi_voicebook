# frozen_string_literal: true

class AddPackageIdToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :package_id, :bigint
    add_index :orders, :package_id
  end
end
