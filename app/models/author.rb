class Author < ApplicationRecord
  has_many :books
  has_many :contents

  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "head_img", "id", "id_value", "name", "updated_at"]
  end
end
