class CreateApiAuths < ActiveRecord::Migration[8.0]
  def change
    create_table :api_auths, comment: "API认证表" do |t|
      t.string :name, null: false, comment: "客户端名称"
      t.string :access_key_id, null: false, comment: "客户端ID"
      t.string :access_key_secret, null: false, comment: "客户端密钥"

      t.timestamps
    end
    add_index :api_auths, :access_key_id, unique: true
  end
end
