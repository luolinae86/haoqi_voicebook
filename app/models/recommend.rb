# frozen_string_literal: true

# == Schema Information
#
# Table name: recommends
#
#  id                               :bigint           not null, primary key
#  name(推荐内容名称)               :string(255)      not null
#  sn(排序)                         :integer          default(0)
#  status(状态: true发布/false草稿) :boolean          default(TRUE)
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#  grade_id(关联年级)               :bigint           not null
#
# Indexes
#
#  index_recommends_on_grade_id         (grade_id)
#  index_recommends_on_grade_id_and_sn  (grade_id,sn)
#
# Foreign Keys
#
#  fk_rails_...  (grade_id => grades.id)
#
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
