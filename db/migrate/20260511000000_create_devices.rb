class CreateDevices < ActiveRecord::Migration[8.0]
  def change
    create_table :devices do |t|
      t.references :app_user, null: false, foreign_key: { to_table: :app_users }
      t.string :device_id, null: false, limit: 64

      t.timestamps
    end

    add_index :devices, :device_id, unique: true

    # Backfill existing data: each app_user with a device_id gets a Device record
    reversible do |dir|
      dir.up do
        AppUser.where.not(device_id: nil).find_each do |user|
          Device.create!(app_user: user, device_id: user.device_id)
        end
      end
    end
  end
end
