class AddUuidToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :uuid, :string, limit: 32
    add_index :users, :uuid, unique: true
  end
end
