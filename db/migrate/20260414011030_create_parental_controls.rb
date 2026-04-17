class CreateParentalControls < ActiveRecord::Migration[8.0]
  def change
    create_table :parental_controls, comment: "家长管控表" do |t|
      t.integer :user_id, null: false, comment: "用户ID"
      t.string :password_digest, null: false, comment: "家长密码"
      t.string :phone, comment: "家长手机号"
      t.integer :time_limit_minutes, comment: "时间限制(分钟)"
      t.boolean :is_active, null: false, default: true, comment: "是否启用"

      t.timestamps
    end
    add_index :parental_controls, :user_id, unique: true
  end
end
