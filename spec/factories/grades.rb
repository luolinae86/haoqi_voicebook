# frozen_string_literal: true

# == Schema Information
#
# Table name: grades
#
#  id          :bigint           not null, primary key
#  description :string(32)
#  group_name  :string(8)
#  level       :integer          default(0), not null
#  name        :string(16)
#  sort_order  :integer          default(0), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_grades_on_level       (level) UNIQUE
#  index_grades_on_sort_order  (sort_order)
#
FactoryBot.define do
  factory :grade do
    sequence(:level) { |n| n }
    name { '三年级' }
    group_name { '小学' }
    description { '小学三年级' }
  end
end
