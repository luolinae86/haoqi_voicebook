# frozen_string_literal: true

FactoryBot.define do
  factory :leaderboard_item do
    association :leaderboard
    association :book
    rank { 1 }
    score { 0.0 }
  end
end
