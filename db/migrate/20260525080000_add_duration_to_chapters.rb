# frozen_string_literal: true

class AddDurationToChapters < ActiveRecord::Migration[8.0]
  def change
    add_column :chapters, :duration, :integer, comment: '音频/视频时长（秒）'
  end
end
