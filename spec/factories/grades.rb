# frozen_string_literal: true

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
FactoryBot.define do
  factory :grade do
    name { "三年级" }
    group_name { "小学" }
    description { "小学三年级" }
  end
end
