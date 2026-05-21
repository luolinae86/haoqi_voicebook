# frozen_string_literal: true

FactoryBot.define do
  factory :chapter do
    association :book
    name { "第一章" }
    sn { 1 }
    is_free { false }
    is_published { true }
    content_file_type { "mp3" }
    content_file_url { "https://cdn.example.com/audio/chapter1.mp3" }
    content_file_name { "chapter1.mp3" }
  end
end
