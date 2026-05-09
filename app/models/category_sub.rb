# frozen_string_literal: true

class CategorySub < ApplicationRecord
  belongs_to :category
  has_and_belongs_to_many :books, join_table: :category_sub_books

  validates :name, presence: true, length: { maximum: 100 }
  validates :category_id, presence: true

  scope :by_category_id, ->(category_id) { where(category_id: category_id) }

  scope :sorted, -> { order(sn: :asc, id: :desc)}
end
