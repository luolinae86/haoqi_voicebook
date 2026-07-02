# frozen_string_literal: true

class AddMediaIdToBooks < ActiveRecord::Migration[8.0]
  def change
    add_column :books, :media_id, :bigint
  end
end
