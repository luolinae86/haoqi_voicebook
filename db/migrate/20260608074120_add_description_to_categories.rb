class AddDescriptionToCategories < ActiveRecord::Migration[8.0]
  def change
    add_column :categories, :description, :string
  end
end
