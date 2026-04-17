class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders, comment: "订单表" do |t|
      t.integer :user_id, null: false, comment: "用户ID"
      t.string :order_no, null: false, comment: "订单号"
      t.decimal :amount, precision: 10, scale: 2, null: false, comment: "金额"
      t.integer :payment_method, null: false, default: 0, comment: "支付方式：0-支付宝 1-微信"
      t.integer :status, null: false, default: 0, comment: "状态：0-待支付 1-已支付 2-失败 3-已退款"
      t.datetime :paid_at, comment: "支付时间"
      t.integer :membership_id, comment: "会员ID"

      t.timestamps
    end
    add_index :orders, :user_id
    add_index :orders, :order_no, unique: true
    add_index :orders, :status
    add_index :orders, :membership_id
  end
end
