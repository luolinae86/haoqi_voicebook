# frozen_string_literal: true

class AddCategorySubIdToContents < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:contents, :category_sub_id)
      add_reference :contents, :category_sub, foreign_key: true, comment: "二级分类"
    end
  end
end
