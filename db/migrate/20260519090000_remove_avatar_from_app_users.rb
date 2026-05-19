class RemoveAvatarFromAppUsers < ActiveRecord::Migration[8.0]
  def change
    remove_column :app_users, :avatar, :string, comment: '头像URL（已废弃，改用 head_img_id）'
  end
end
