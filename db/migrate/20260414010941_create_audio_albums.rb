class CreateAudioAlbums < ActiveRecord::Migration[8.0]
  def change
    create_table :audio_albums, comment: "有声专辑表" do |t|
      t.integer :book_id, null: false, comment: "图书ID"
      t.string :narrator, comment: "主讲人/播音员"
      t.integer :total_episodes, null: false, default: 0, comment: "总集数"
      t.integer :total_duration, null: false, default: 0, comment: "总时长(秒)"
      t.text :description, comment: "专辑简介"

      t.timestamps
    end
    add_index :audio_albums, :book_id, unique: true
  end
end
