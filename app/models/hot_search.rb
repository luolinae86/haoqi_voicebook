# frozen_string_literal: true

class HotSearch < ApplicationRecord
  validates :keyword, presence: true, uniqueness: true

  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(sort_order: :asc) }
end
