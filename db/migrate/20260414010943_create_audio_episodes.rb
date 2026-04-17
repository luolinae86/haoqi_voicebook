class CreateAudioEpisodes < ActiveRecord::Migration[8.0]
  def change
    create_table :audio_episodes, comment: "有声节目表" do |t|
      t.integer :audio_album_id, null: false, comment: "专辑ID"
      t.string :title, null: false, comment: "节目标题"
      t.integer :sort_order, null: false, default: 0, comment: "排序"
      t.string :audio_url, comment: "音频URL"
      t.integer :duration, null: false, default: 0, comment: "时长(秒)"
      t.integer :play_count, null: false, default: 0, comment: "播放次数"
      t.boolean :is_free, null: false, default: false, comment: "是否免费"
      t.boolean :is_vip, null: false, default: false, comment: "是否VIP"
      t.datetime :published_at, comment: "发布时间"

      t.timestamps
    end
    add_index :audio_episodes, :audio_album_id
    add_index :audio_episodes, [:audio_album_id, :sort_order]
  end
end
