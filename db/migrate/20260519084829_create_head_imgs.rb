class CreateHeadImgs < ActiveRecord::Migration[8.0]
  def change
    create_table :head_imgs, if_not_exists: true do |t|
      t.string :img_url, limit: 255, comment: '头像URL'
      t.boolean :is_vip, default: false, comment: '是否VIP用户可用'
      t.timestamps
    end
  end
end
