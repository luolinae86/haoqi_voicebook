# frozen_string_literal: true

FactoryBot.define do
  factory :content do
    association :content_group
    content_type { "book" }
    sn { 0 }
  end
end
