# frozen_string_literal: true

class EbookPage < ApplicationRecord
  belongs_to :book

  validates :page_number, presence: true, uniqueness: { scope: :book_id }
  validates :page_width, :page_height, presence: true
  validates :word_count, :block_count, :image_count, numericality: { greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(page_number: :asc) }
  scope :before_page, ->(page_number) { where("page_number < ?", page_number) }
  scope :after_page, ->(page_number) { where("page_number > ?", page_number) }
end
