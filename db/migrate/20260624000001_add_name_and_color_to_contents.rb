# frozen_string_literal: true

class AddNameAndColorToContents < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:contents, :name)
      add_column :contents, :name, :string, limit: 16, comment: "名称"
    end
    unless column_exists?(:contents, :color)
      add_column :contents, :color, :string, limit: 16, comment: "颜色"
    end
  end
end
