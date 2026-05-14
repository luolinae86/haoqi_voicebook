# frozen_string_literal: true

# == Schema Information
#
# Table name: suppliers
#
#  id               :bigint           not null, primary key
#  name(供应商名称) :string(255)      not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_suppliers_on_name  (name)
#
FactoryBot.define do
  factory :supplier do
    name { Faker::Company.name }
  end
end
