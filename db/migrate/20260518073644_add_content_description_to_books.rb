class AddContentDescriptionToBooks < ActiveRecord::Migration[8.0]
  def change
    add_column :books, :content_description, :text
  end
end
