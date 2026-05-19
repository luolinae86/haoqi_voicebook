class AddHeadImgIdToAppUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :app_users, :head_img_id, :bigint, comment: '用户头像ID'
  end
end
