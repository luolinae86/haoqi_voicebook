# frozen_string_literal: true

# == Schema Information
#
# Table name: categories
#
#  id          :bigint           not null, primary key
#  active      :boolean          default(TRUE)
#  description :string(255)
#  icon        :string(255)
#  level       :integer          default(1), not null
#  name        :string(255)      not null
#  sn          :integer          default(0)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_categories_on_level  (level)
#
FactoryBot.define do
  factory :category do
    name { Faker::Book.genre }
    level { 1 }
    sn { 0 }
    active { true }
  end
end
