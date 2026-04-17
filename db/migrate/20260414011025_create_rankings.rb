class CreateRankings < ActiveRecord::Migration[8.0]
  def change
    create_table :rankings, comment: "排行榜表" do |t|
      t.string :name, null: false, comment: "榜单名称"
      t.integer :ranking_type, null: false, default: 0, comment: "类型：0-热度 1-高分 2-上新 3-大奖 4-名著"
      t.string :description, comment: "描述"

      t.timestamps
    end
    add_index :rankings, :ranking_type
  end
end
