class CreateChannels < ActiveRecord::Migration[7.1]
  def change
    return if table_exists?(:channels)

    create_table :channels do |t|
      t.string :name
      t.string :version
      t.timestamps
    end
  end
end