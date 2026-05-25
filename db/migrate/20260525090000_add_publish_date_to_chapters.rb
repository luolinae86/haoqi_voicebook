# frozen_string_literal: true

class AddPublishDateToChapters < ActiveRecord::Migration[8.0]
  def change
    add_column :chapters, :publish_date, :date, comment: '发布日期'
  end
end
