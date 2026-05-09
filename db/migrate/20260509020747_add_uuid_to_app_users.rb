class AddUuidToAppUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :app_users, :uuid, :string, null: false
    add_index :app_users, :uuid, unique: true
  end
end
