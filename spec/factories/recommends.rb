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
FactoryBot.define do
  factory :recommend do
    association :grade
    name { "推荐内容#{Faker::Number.number(digits: 2)}" }
    sn { 0 }
    status { true }
  end
end
