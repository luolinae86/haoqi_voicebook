# frozen_string_literal: true

FactoryBot.define do
  factory :chapter do
    association :book
    name { "第#{Faker::Number.number(digits: 1)}章" }
    content_file_type { "pdf" }
    content_file_url { "http://zheli.oss-cn-beijing.aliyuncs.com/chapters/test.pdf" }
    content_file_name { "test.pdf" }
    is_free { false }
    is_published { true }
    sn { 0 }
  end
end
