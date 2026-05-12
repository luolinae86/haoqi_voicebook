# == Schema Information
#
# Table name: authors
#
#  id             :bigint           not null, primary key
#  head_img(头像) :string(255)      not null
#  name(作者名)   :string(255)      not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
class Author < ApplicationRecord
  has_many :books
  has_many :contents

  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "head_img", "id", "id_value", "name", "updated_at"]
  end
end
