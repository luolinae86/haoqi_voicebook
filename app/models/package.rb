# frozen_string_literal: true

# == Schema Information
#
# Table name: packages
#
#  id             :bigint           not null, primary key
#  discount_tag   :string(255)
#  effective_days :integer
#  is_delete      :boolean          default(FALSE)
#  is_discount    :boolean          default(FALSE)
#  name           :string(255)
#  origin_price   :float(24)
#  price          :float(24)
#  sn             :integer          default(0)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_packages_on_is_delete  (is_delete)
#
class Package < ApplicationRecord
  default_scope { where(is_delete: false).order(sn: :asc, id: :desc) }

  validates :name, presence: true, length: { maximum: 100 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(is_delete: false) }
  scope :sorted, -> { order(sn: :asc, id: :desc) }
  scope :ordered_by_price, -> { where(is_delete: false).reorder(price: :desc) }
end
