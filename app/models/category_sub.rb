# frozen_string_literal: true

# == Schema Information
#
# Table name: category_subs
#
#  id                    :bigint           not null, primary key
#  icon(图标URL)         :string(255)
#  name(子类名称)        :string(255)      not null
#  sn(排序)              :integer          default(0)
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  category_id(关联分类) :bigint           not null
#
# Indexes
#
#  index_category_subs_on_category_id  (category_id)
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id)
#
class CategorySub < ApplicationRecord
  belongs_to :category
  has_and_belongs_to_many :books, join_table: :category_sub_books

  validates :name, presence: true, length: { maximum: 100 }
  validates :category_id, presence: true

  scope :by_category_id, ->(category_id) { where(category_id: category_id) }

  scope :sorted, -> { order(sn: :asc, id: :desc)}
end
