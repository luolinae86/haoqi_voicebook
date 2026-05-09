# frozen_string_literal: true

FactoryBot.define do
  factory :chapter do
    association :book
    name { "第#{Faker::Number.number(digits: 1)}章" }
    content_file_type { "epub" }
    is_free { false }
    is_published { false }
    sn { 0 }
  end
end
