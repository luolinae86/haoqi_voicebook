class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users, comment: "用户表" do |t|
      t.string :phone, null: false, comment: "手机号"
      t.string :password_digest, comment: "加密密码"
      t.string :nickname, comment: "昵称"
      t.string :avatar, comment: "头像URL"
      t.integer :grade_id, comment: "年级ID"
      t.integer :role, null: false, default: 0, comment: "角色：0-孩子 1-家长 2-管理员"
      t.integer :reading_words, null: false, default: 0, comment: "阅读字数"
      t.integer :reading_minutes, null: false, default: 0, comment: "阅读时长(分钟)"
      t.integer :books_read, null: false, default: 0, comment: "读过的书(本)"
      t.boolean :is_vip, null: false, default: false, comment: "是否VIP"
      t.datetime :vip_expires_at, comment: "VIP过期时间"

      t.timestamps
    end
    add_index :users, :phone, unique: true
    add_index :users, :grade_id
    add_index :users, :is_vip
  end
end
