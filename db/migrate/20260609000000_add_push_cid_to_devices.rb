# frozen_string_literal: true

class AddPushCidToDevices < ActiveRecord::Migration[8.0]
  def change
    add_column :devices, :push_cid, :string, limit: 64

    add_index :devices, :push_cid
  end
end
