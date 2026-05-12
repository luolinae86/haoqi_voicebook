# == Schema Information
#
# Table name: suppliers
#
#  id               :bigint           not null, primary key
#  name(供应商名称) :string(255)      not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_suppliers_on_name  (name)
#
class Supplier < ApplicationRecord
  validates :name, presence: true, length: { maximum: 100 }, uniqueness: true
end
