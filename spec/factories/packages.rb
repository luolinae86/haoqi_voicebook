# frozen_string_literal: true

# == Schema Information
#
# Table name: packages
#
#  id             :bigint           not null, primary key
#  discount_tag   :string(255)
#  effective_days :integer
#  is_delete      :boolean          default("0")
#  is_discount    :boolean          default("0")
#  name           :string(255)
#  origin_price   :float
#  price          :float
#  sn             :integer          default(0)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
FactoryBot.define do
  factory :package do
    name { "月套餐" }
    price { 19.9 }
    origin_price { 29.9 }
    effective_days { 30 }
    sn { 0 }
    is_delete { false }
    is_discount { false }
    discount_tag { "限时优惠" }
  end
end
