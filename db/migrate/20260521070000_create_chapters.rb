class CreateChapters < ActiveRecord::Migration[8.0]
  def up
    return if table_exists?(:chapters)

    create_table :chapters, charset: 'utf8mb4', collation: 'utf8mb4_unicode_ci', comment: '章节表（有声/视频章节）' do |t|
      t.bigint :book_id, null: false, comment: '所属图书'
      t.string :name, null: false, comment: '章节名称'
      t.string :cover_image_url, comment: '章节封面图片URL'
      t.string :content_file_url, comment: '章节内容文件URL（音频/视频）'
      t.string :content_file_name, comment: '章节内容文件名'
      t.string :content_file_type, comment: '内容文件类型 (mp3/mp4/wav等)'
      t.boolean :is_free, default: false, comment: '是否免费'
      t.boolean :is_published, default: false, comment: '是否已发布'
      t.integer :sn, default: 0, comment: '排序'

      t.timestamps
    end
    add_index :chapters, :book_id
  end

  def down
    drop_table :chapters if table_exists?(:chapters)
  end
end
