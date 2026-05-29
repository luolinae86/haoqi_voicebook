class CreateRanks < ActiveRecord::Migration[8.0]
  def change
    create_table :ranks do |t|
      t.references :grade, null: false, index: true
      t.references :category, index: true
      t.string :name, null: false
      t.integer :sn, default: 0

      t.timestamps
    end
  end
end
