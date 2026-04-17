class CreateMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :memberships, comment: "会员表" do |t|
      t.integer :user_id, null: false, comment: "用户ID"
      t.integer :plan_type, null: false, default: 0, comment: "套餐：0-月度 1-季度 2-年度"
      t.decimal :price, precision: 10, scale: 2, null: false, comment: "实付价格"
      t.decimal :original_price, precision: 10, scale: 2, comment: "原价"
      t.date :start_date, null: false, comment: "开始日期"
      t.date :end_date, null: false, comment: "结束日期"
      t.integer :status, null: false, default: 0, comment: "状态：0-待支付 1-有效 2-已过期 3-已取消"

      t.timestamps
    end
    add_index :memberships, :user_id
    add_index :memberships, :status
    add_index :memberships, :end_date
  end
end
