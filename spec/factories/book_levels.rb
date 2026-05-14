# frozen_string_literal: true

# == Schema Information
#
# Table name: book_levels
#
#  id             :bigint           not null, primary key
#  name(等级名称) :string(50)       not null
#  sn(序号)       :integer          default(0), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
FactoryBot.define do
  factory :book_level do
    name { "Level #{Faker::Number.between(from: 1, to: 10)}" }
    sn { Faker::Number.between(from: 1, to: 100) }
  end
end
