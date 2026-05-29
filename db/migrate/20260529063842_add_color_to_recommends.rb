class AddColorToRecommends < ActiveRecord::Migration[8.0]
  def change
    add_column :recommends, :color, :string, default: ""
  end
end
