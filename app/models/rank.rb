# frozen_string_literal: true

# == Schema Information
#
# Table name: ranks
#
#  id          :bigint           not null, primary key
#  name        :string(255)      not null
#  sn          :integer          default(0)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  category_id :bigint
#  grade_id    :bigint           not null
#
# Indexes
#
#  index_ranks_on_category_id  (category_id)
#  index_ranks_on_grade_id     (grade_id)
#
class Rank < ApplicationRecord
  belongs_to :grade
  belongs_to :category, optional: true
  has_many :rank_contents, dependent: :destroy
  has_many :contents, dependent: :destroy

  def content_names
    res = []
    rank_contents.each do |x|
      res << x.content_name
    end
    res.join(' | ')
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[category_id created_at grade_id id id_value name sn updated_at]
  end
end
