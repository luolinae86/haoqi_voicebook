class Channel < ApplicationRecord
  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "id", "id_value", "name", "updated_at", "version"]
  end
end