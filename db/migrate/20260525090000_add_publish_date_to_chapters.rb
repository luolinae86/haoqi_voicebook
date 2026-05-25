# frozen_string_literal: true

class AddPublishDateToChapters < ActiveRecord::Migration[8.0]
  def up
    add_column :chapters, :publish_date, :date, comment: '发布日期' unless column_exists?(:chapters, :publish_date)
  end

  def down
    remove_column :chapters, :publish_date if column_exists?(:chapters, :publish_date)
  end
end
