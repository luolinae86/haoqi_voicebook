# frozen_string_literal: true

class Recommend < ApplicationRecord
  belongs_to :grade
  has_many :content_groups, dependent: :destroy

  validates :name, presence: true, length: { maximum: 10 }
  validates :grade_id, presence: true

  default_scope { order(sn: :asc, id: :desc) }
  scope :sorted, -> { order(sn: :asc, id: :desc) }

  def status_text
    published? ? '已发布' : '未发布'
  end
end
