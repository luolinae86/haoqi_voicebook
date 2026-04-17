class CreateSmsVerifications < ActiveRecord::Migration[8.0]
  def change
    create_table :sms_verifications, comment: "短信验证码表" do |t|
      t.string :phone, null: false, comment: "手机号"
      t.string :code, null: false, comment: "验证码"
      t.boolean :verified, null: false, default: false, comment: "是否已验证"
      t.datetime :expires_at, null: false, comment: "过期时间"

      t.timestamps
    end
    add_index :sms_verifications, [:phone, :code]
    add_index :sms_verifications, :expires_at
  end
end
