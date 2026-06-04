# == Schema Information
#
# Table name: grades
#
#  id          :bigint           not null, primary key
#  description :string(32)
#  group_name  :string(8)
#  name        :string(16)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class Grade < ApplicationRecord
  has_and_belongs_to_many :compilations, join_table: :compilation_grades
  has_and_belongs_to_many :books, join_table: :book_grades

  has_many :recommends, dependent: :destroy

  GROUP_ORDER = %w[学龄前 小学 初中 高中].freeze

  scope :by_group_order, lambda {
    order(Arel.sql("FIELD(group_name, #{GROUP_ORDER.map { |g| "'#{g}'" }.join(', ')})"))
  }
end
