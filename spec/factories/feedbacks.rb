# frozen_string_literal: true

FactoryBot.define do
  factory :feedback do
    association :app_user
    feedback_type { :bug }
    content { '这个功能有问题' }
    status { :pending }

    trait :with_images do
      images { '["https://example.com/img1.jpg", "https://example.com/img2.jpg"]' }
    end

    trait :content_suggestion do
      feedback_type { :content_suggestion }
      content { '建议增加更多科普类书籍' }
    end

    trait :other do
      feedback_type { :other }
      content { '其他反馈内容' }
    end
  end
end
