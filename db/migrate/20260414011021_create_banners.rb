class CreateBanners < ActiveRecord::Migration[8.0]
  def change
    create_table :banners, comment: "轮播广告表" do |t|
      t.string :title, null: false, comment: "标题"
      t.string :image_url, null: false, comment: "图片URL"
      t.string :link_url, comment: "链接URL"
      t.integer :link_type, null: false, default: 3, comment: "链接类型：0-图书 1-合集 2-URL 3-无"
      t.integer :position, null: false, default: 0, comment: "位置"
      t.integer :sort_order, null: false, default: 0, comment: "排序"
      t.datetime :starts_at, comment: "开始时间"
      t.datetime :ends_at, comment: "结束时间"
      t.boolean :is_active, null: false, default: true, comment: "是否激活"

      t.timestamps
    end
    add_index :banners, :is_active
    add_index :banners, :sort_order
  end
end
