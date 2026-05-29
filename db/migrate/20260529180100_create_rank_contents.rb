class CreateRankContents < ActiveRecord::Migration[8.0]
  def change
    create_table :rank_contents, if_not_exists: true do |t|
      t.references :rank, null: false, index: true
      t.references :compilation, index: true
      t.references :book, index: true
      t.string :content_type, null: false, default: 'book'
      t.integer :sn, default: 0

      t.timestamps
    end
  end
end
